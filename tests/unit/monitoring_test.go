package unit

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestMonitoringPlanWithFixture(t *testing.T) {
	t.Parallel()

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/monitoring",
		VarFiles:     []string{"../test-fixtures/monitoring.tfvars"},
		NoColor:      true,
	})

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	require.NoError(t, err)
}

func TestMonitoringCpuThresholdValidation(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../../modules/monitoring",
		Vars: map[string]interface{}{
			"project_id":                "test-project",
			"service_name":              "test-svc",
			"service_location":          "us-central1",
			"cpu_utilization_threshold": 80, // must fail validation (> 1)
		},
		NoColor: true,
	}

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	require.Error(t, err, "cpu_utilization_threshold of 80 must violate the (0,1] bound")
}
