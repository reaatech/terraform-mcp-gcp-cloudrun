package unit

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSecretsPlanWithFixture(t *testing.T) {
	t.Parallel()

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/secrets",
		VarFiles:     []string{"../test-fixtures/secrets.tfvars"},
		NoColor:      true,
	})

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	require.NoError(t, err)
}

func TestSecretsPlanCreatesSecretsAndIAM(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../../modules/secrets",
		Vars: map[string]interface{}{
			"project_id": "test-project",
			"secrets": map[string]interface{}{
				"api-key": map[string]interface{}{
					"secret_id": "mcp-api-key",
				},
			},
			"accessors": []string{
				"serviceAccount:sa-a@test-project.iam.gserviceaccount.com",
				"serviceAccount:sa-b@test-project.iam.gserviceaccount.com",
			},
		},
		NoColor: true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	secret, ok := plan.ResourcePlannedValuesMap[`google_secret_manager_secret.this["api-key"]`]
	require.True(t, ok)
	assert.Equal(t, "mcp-api-key", secret.AttributeValues["secret_id"])

	iamCount := 0
	for addr := range plan.ResourcePlannedValuesMap {
		if strings.HasPrefix(addr, "google_secret_manager_secret_iam_member.accessor") {
			iamCount++
		}
	}
	assert.Equal(t, 2, iamCount, "one IAM binding per accessor")
}
