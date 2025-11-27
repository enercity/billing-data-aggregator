package export

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/rs/zerolog/log"
)

type S3Uploader struct {
	client *s3.Client
	bucket string
	prefix string
}

func NewS3Uploader(ctx context.Context, region, bucket, prefix string) (*S3Uploader, error) {
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	return &S3Uploader{
		client: s3.NewFromConfig(cfg),
		bucket: bucket,
		prefix: prefix,
	}, nil
}

func (u *S3Uploader) UploadFile(ctx context.Context, localPath string) error {
	log.Info().Str("file", localPath).Msg("Uploading to S3")

	// #nosec G304 -- localPath comes from CSVExporter output, not user input
	file, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			log.Error().Err(err).Msg("Failed to close file")
		}
	}()

	key := filepath.Join(u.prefix, filepath.Base(localPath))
	maxRetries := 3
	var lastErr error

	for retry := 0; retry < maxRetries; retry++ {
		if retry > 0 {
			waitTime := time.Duration(retry*5) * time.Second
			log.Warn().Int("retry", retry).Dur("wait", waitTime).Msg("Retrying upload")
			time.Sleep(waitTime)
		}

		_, lastErr = u.client.PutObject(ctx, &s3.PutObjectInput{
			Bucket: aws.String(u.bucket),
			Key:    aws.String(key),
			Body:   file,
		})

		if lastErr == nil {
			log.Info().Str("bucket", u.bucket).Str("key", key).Msg("Upload successful")
			return nil
		}

		if _, err := file.Seek(0, 0); err != nil {
			return fmt.Errorf("failed to reset file: %w", err)
		}
	}

	return fmt.Errorf("upload failed after %d retries: %w", maxRetries, lastErr)
}

func (u *S3Uploader) UploadFiles(ctx context.Context, files []string) error {
	for _, file := range files {
		if err := u.UploadFile(ctx, file); err != nil {
			return fmt.Errorf("failed to upload %s: %w", file, err)
		}
	}
	log.Info().Int("count", len(files)).Msg("All files uploaded")
	return nil
}
