package unit

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIamPlanWithFixture(t *testing.T) {
	t.Parallel()

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/iam",
		VarFiles:     []string{"../test-fixtures/iam.tfvars"},
		NoColor:      true,
	})

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	require.NoError(t, err)
}

func TestIamPlanCreatesServiceAccount(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../../modules/iam",
		Vars: map[string]interface{}{
			"project_id": "test-project",
			"service_accounts": map[string]interface{}{
				"mcp-sa": map[string]interface{}{
					"account_id": "mcp-sa",
				},
			},
		},
		NoColor: true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	sa, ok := plan.ResourcePlannedValuesMap[`google_service_account.this["mcp-sa"]`]
	require.True(t, ok)
	assert.Equal(t, "mcp-sa", sa.AttributeValues["account_id"])
}
