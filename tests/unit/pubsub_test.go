package unit

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPubsubPlanWithFixture(t *testing.T) {
	t.Parallel()

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/pubsub",
		VarFiles:     []string{"../test-fixtures/pubsub.tfvars"},
		NoColor:      true,
	})

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	require.NoError(t, err)
}

func TestPubsubPlanDLQTopicCreated(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../../modules/pubsub",
		Vars: map[string]interface{}{
			"project_id": "test-project",
			"topics":     []string{"mcp-tasks"},
			"subscriptions": map[string]interface{}{
				"mcp-tasks-sub": map[string]interface{}{
					"topic":             "mcp-tasks",
					"dead_letter_topic": "mcp-dlq",
				},
			},
			"dead_letter_topic": "mcp-dlq",
		},
		NoColor: true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	_, mainOK := plan.ResourcePlannedValuesMap[`google_pubsub_topic.this["mcp-tasks"]`]
	_, dlqOK := plan.ResourcePlannedValuesMap[`google_pubsub_topic.dlq["mcp-dlq"]`]
	assert.True(t, mainOK, "main topic should be planned")
	assert.True(t, dlqOK, "dlq topic should be planned")
}

func TestPubsubSubscriptionReferencesUnknownTopicFails(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../../modules/pubsub",
		Vars: map[string]interface{}{
			"project_id": "test-project",
			"topics":     []string{"mcp-tasks"},
			"subscriptions": map[string]interface{}{
				"bad-sub": map[string]interface{}{
					"topic": "does-not-exist",
				},
			},
		},
		NoColor: true,
	}

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	assert.Error(t, err, "subscription referencing undefined topic should fail the precondition")
}
