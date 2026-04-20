package unit

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Common required variables for plan-only tests of the cloud-run module.
func cloudRunBaseVars() map[string]interface{} {
	return map[string]interface{}{
		"name":                  "test-svc",
		"project_id":            "test-project",
		"region":                "us-central1",
		"image":                 "gcr.io/test/test:latest",
		"service_account_email": "test@test.iam.gserviceaccount.com",
	}
}

func TestCloudRunPlanWithFixture(t *testing.T) {
	t.Parallel()

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		VarFiles:     []string{"../test-fixtures/cloud-run.tfvars"},
		NoColor:      true,
	})

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	require.NoError(t, err)
}

func TestCloudRunPlanScaling(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["min_instances"] = 2
	vars["max_instances"] = 20

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	svc, ok := plan.ResourcePlannedValuesMap["google_cloud_run_v2_service.this"]
	require.True(t, ok, "plan should include google_cloud_run_v2_service.this")

	template := svc.AttributeValues["template"].([]interface{})[0].(map[string]interface{})
	scaling := template["scaling"].([]interface{})[0].(map[string]interface{})
	assert.EqualValues(t, 2, scaling["min_instance_count"])
	assert.EqualValues(t, 20, scaling["max_instance_count"])
}

func TestCloudRunPlanResources(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["cpu"] = "2000m"
	vars["memory"] = "1024Mi"
	vars["timeout_seconds"] = 120
	vars["concurrency"] = 50

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	svc, ok := plan.ResourcePlannedValuesMap["google_cloud_run_v2_service.this"]
	require.True(t, ok)

	template := svc.AttributeValues["template"].([]interface{})[0].(map[string]interface{})
	assert.Equal(t, "120s", template["timeout"])
	assert.EqualValues(t, 50, template["max_instance_request_concurrency"])

	container := template["containers"].([]interface{})[0].(map[string]interface{})
	resources := container["resources"].([]interface{})[0].(map[string]interface{})
	limits := resources["limits"].(map[string]interface{})
	assert.Equal(t, "2000m", limits["cpu"])
	assert.Equal(t, "1024Mi", limits["memory"])
}

func TestCloudRunPlanIngress(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["ingress"] = "internal"

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	svc := plan.ResourcePlannedValuesMap["google_cloud_run_v2_service.this"]
	assert.Equal(t, "internal", svc.AttributeValues["ingress"])
}

func TestCloudRunPlanSecretEnvVars(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["secret_env_vars"] = map[string]interface{}{
		"API_KEY": map[string]string{
			"secret":  "my-api-key",
			"version": "latest",
		},
	}

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	svc := plan.ResourcePlannedValuesMap["google_cloud_run_v2_service.this"]
	template := svc.AttributeValues["template"].([]interface{})[0].(map[string]interface{})
	container := template["containers"].([]interface{})[0].(map[string]interface{})
	envs := container["env"].([]interface{})

	found := false
	for _, e := range envs {
		env := e.(map[string]interface{})
		if env["name"] == "API_KEY" {
			vs := env["value_source"].([]interface{})[0].(map[string]interface{})
			ref := vs["secret_key_ref"].([]interface{})[0].(map[string]interface{})
			assert.Equal(t, "my-api-key", ref["secret"])
			assert.Equal(t, "latest", ref["version"])
			found = true
		}
	}
	assert.True(t, found, "API_KEY secret env var should be present")
}

func TestCloudRunPlanVpcConnector(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["vpc_connector"] = "my-vpc-connector"

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	svc := plan.ResourcePlannedValuesMap["google_cloud_run_v2_service.this"]
	template := svc.AttributeValues["template"].([]interface{})[0].(map[string]interface{})
	vpcAccess := template["vpc_access"].([]interface{})[0].(map[string]interface{})
	assert.Equal(t, "my-vpc-connector", vpcAccess["connector"])
}

func TestCloudRunPlanAllowUnauthenticated(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["allow_unauthenticated"] = true

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	iam, ok := plan.ResourcePlannedValuesMap["google_cloud_run_v2_service_iam_member.unauthenticated[0]"]
	require.True(t, ok, "unauthenticated IAM member should be planned")
	assert.Equal(t, "allUsers", iam.AttributeValues["member"])
}

func TestCloudRunPlanInvokerMembers(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["invoker_members"] = []string{"serviceAccount:other@project.iam.gserviceaccount.com"}

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	found := false
	for addr := range plan.ResourcePlannedValuesMap {
		if addr == `google_cloud_run_v2_service_iam_member.invoker["serviceAccount:other@project.iam.gserviceaccount.com"]` {
			found = true
			break
		}
	}
	assert.True(t, found, "plan should contain invoker IAM member")
}

func TestCloudRunIngressValidation(t *testing.T) {
	t.Parallel()

	vars := cloudRunBaseVars()
	vars["ingress"] = "invalid-ingress"

	opts := &terraform.Options{
		TerraformDir: "../../modules/cloud-run",
		Vars:         vars,
		NoColor:      true,
	}

	_, err := terraform.InitE(t, opts)
	require.NoError(t, err)

	_, err = terraform.PlanE(t, opts)
	assert.Error(t, err, "plan should fail with invalid ingress value")
}
