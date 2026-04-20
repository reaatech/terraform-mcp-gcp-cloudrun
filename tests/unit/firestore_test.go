package unit

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestFirestorePlanWithFixture(t *testing.T) {
	t.Parallel()

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/firestore",
		VarFiles:     []string{"../test-fixtures/firestore.tfvars"},
		NoColor:      true,
	})

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	require.NoError(t, err)
}

func TestFirestorePlanDefaults(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../../modules/firestore",
		Vars: map[string]interface{}{
			"project_id": "test-project",
			"location":   "us-central",
		},
		NoColor: true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	db, ok := plan.ResourcePlannedValuesMap["google_firestore_database.this"]
	require.True(t, ok)
	assert.Equal(t, "FIRESTORE_NATIVE", db.AttributeValues["type"])
	assert.Equal(t, "DELETE_PROTECTION_ENABLED", db.AttributeValues["delete_protection_state"])
}

func TestFirestorePlanSkipIndexes(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../../modules/firestore",
		Vars: map[string]interface{}{
			"project_id":             "test-project",
			"location":               "us-central",
			"create_session_indexes": false,
		},
		NoColor: true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	_, hasUserIdx := plan.ResourcePlannedValuesMap["google_firestore_index.session_user_status[0]"]
	_, hasLookupIdx := plan.ResourcePlannedValuesMap["google_firestore_index.session_lookup[0]"]
	assert.False(t, hasUserIdx, "session_user_status index should not be planned when create_session_indexes=false")
	assert.False(t, hasLookupIdx, "session_lookup index should not be planned when create_session_indexes=false")
}
