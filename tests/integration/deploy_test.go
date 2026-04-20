package integration

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMcpCloudRunDeployment(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT_ID")
	if projectID == "" {
		t.Skip("GOOGLE_PROJECT_ID not set, skipping integration test")
	}

	uniqueID := random.UniqueId()
	serviceName := fmt.Sprintf("mcp-test-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../examples/basic",
		VarFiles:     []string{"../test-fixtures/integration.tfvars"},
		Vars: map[string]interface{}{
			"project_id":       projectID,
			"mcp_server_name":  serviceName,
			"mcp_server_image": "gcr.io/google-samples/hello-app:1.0",
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceURL := terraform.Output(t, terraformOptions, "mcp_server_url")
	serviceAccount := terraform.Output(t, terraformOptions, "service_account_email")

	assert.NotEmpty(t, serviceURL, "Service URL should not be empty")
	assert.NotEmpty(t, serviceAccount, "Service account email should not be empty")

	region := "us-central1"
	service := gcp.GetCloudRunService(t, serviceName, region, projectID)
	assert.Equal(t, serviceName, service.Name)

	maxRetries := 10
	sleepBetweenRetries := 10 * time.Second

	expectedStatus := "200"
	_, err := retry.DoWithRetryE(t, "Check health endpoint", maxRetries, sleepBetweenRetries, func() (string, error) {
		statusCode, err := gcp.MakeGetRequestWithRetry(t, fmt.Sprintf("%s/health", serviceURL), expectedStatus, 1)
		if err != nil {
			return "", err
		}
		if statusCode != expectedStatus {
			return "", fmt.Errorf("Expected status %s, got %s", expectedStatus, statusCode)
		}
		return "Success", nil
	})

	require.NoError(t, err, "Health endpoint should return 200")
}

func TestMcpCloudRunMultiServiceDeployment(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT_ID")
	if projectID == "" {
		t.Skip("GOOGLE_PROJECT_ID not set, skipping integration test")
	}

	uniqueID := random.UniqueId()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../examples/multi-service",
		VarFiles:     []string{"../test-fixtures/integration.tfvars"},
		Vars: map[string]interface{}{
			"project_id":         projectID,
			"orchestrator_image": "gcr.io/google-samples/hello-app:1.0",
			"agents": []map[string]interface{}{
				{"name": fmt.Sprintf("agent-a-%s", uniqueID), "image": "gcr.io/google-samples/hello-app:2.0"},
				{"name": fmt.Sprintf("agent-b-%s", uniqueID), "image": "gcr.io/google-samples/hello-app:1.0"},
			},
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceURLs := terraform.OutputMap(t, terraformOptions, "service_urls")
	assert.NotEmpty(t, serviceURLs, "Should have service URLs")

	pubsubTopics := terraform.OutputMap(t, terraformOptions, "pubsub_topics")
	assert.NotEmpty(t, pubsubTopics, "Should have Pub/Sub topics")

	dashboardURLs := terraform.OutputMap(t, terraformOptions, "monitoring_dashboard_urls")
	assert.NotEmpty(t, dashboardURLs, "Should have per-service dashboard URLs")
}

func TestMcpCloudRunVpcScDeployment(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT_ID")
	if projectID == "" {
		t.Skip("GOOGLE_PROJECT_ID not set, skipping integration test")
	}

	uniqueID := random.UniqueId()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../examples/vpc-sc",
		Vars: map[string]interface{}{
			"project_id":       projectID,
			"mcp_server_name":  fmt.Sprintf("mcp-vpc-test-%s", uniqueID),
			"mcp_server_image": "gcr.io/google-samples/hello-app:1.0",
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	serviceURL := terraform.Output(t, terraformOptions, "mcp_server_url")
	assert.NotEmpty(t, serviceURL, "Service URL should not be empty")

	firestoreDB := terraform.Output(t, terraformOptions, "firestore_database")
	assert.NotEmpty(t, firestoreDB, "Firestore database should not be empty")
}

func TestOutputsNotEmpty(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT_ID")
	if projectID == "" {
		t.Skip("GOOGLE_PROJECT_ID not set, skipping integration test")
	}

	uniqueID := random.UniqueId()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../examples/basic",
		VarFiles:     []string{"../test-fixtures/integration.tfvars"},
		Vars: map[string]interface{}{
			"project_id":       projectID,
			"mcp_server_name":  fmt.Sprintf("mcp-outputs-test-%s", uniqueID),
			"mcp_server_image": "gcr.io/google-samples/hello-app:1.0",
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	logger.Log(t, "Validating outputs")

	outputs := []string{
		"mcp_server_url",
		"mcp_server_name",
		"service_account_email",
		"firestore_database",
		"monitoring_dashboard_url",
	}

	for _, outputName := range outputs {
		outputValue := terraform.Output(t, terraformOptions, outputName)
		assert.NotEmpty(t, outputValue, "Output %s should not be empty", outputName)
	}
}
