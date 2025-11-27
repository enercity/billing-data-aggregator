package processors

import "testing"

func TestProcessorInterface(t *testing.T) {
	var _ Processor = &TripicaProcessor{}
	var _ Processor = &BookkeeperProcessor{}
}
