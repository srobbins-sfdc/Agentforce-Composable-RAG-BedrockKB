# Composable RAG with Salesforce Agentforce + AWS Bedrock Knowledge Bases

A Salesforce DX project that connects **Agentforce agents** to an **AWS Bedrock Knowledge Base** using Retrieval-Augmented Generation (RAG). When a user asks an agent a question, relevant content is retrieved from a curated knowledge base, injected into a Prompt Template, and used by the agent's LLM to generate a grounded, accurate response.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          SALESFORCE                                      │
│                                                                          │
│  User / Channel  ──▶  Agentforce Agent  ──▶  Prompt Template Action    │
│                                                        │                 │
│                              ┌─────────────────────────┘                │
│                              ▼                                           │
│                    BedrockKBPromptBuilder (Apex)                         │
│                              │                                           │
│                    Named Credential  ──  External Credential             │
│                    (endpoint URL)        (AWS Sig V4 + IAM keys)         │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │  HTTPS · AWS Signature Version 4
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       AMAZON WEB SERVICES                                │
│                                                                          │
│  Bedrock Agent Runtime  ──▶  Knowledge Base  ──▶  OpenSearch Serverless │
│                                    │                  (vector store)     │
│                                    └──▶  S3 (source documents)          │
│                                                                          │
│  IAM User: salesforce-bedrock-integration                                │
│  Policy:   bedrock:Retrieve, bedrock:RetrieveAndGenerate,                │
│            bedrock:InvokeModel, bedrock:GetInferenceProfile              │
└─────────────────────────────────────────────────────────────────────────┘

REQUEST FLOW (Retrieve path)
  1. User asks agent a question
  2. Agent selects relevant Subagent and invokes the Prompt Template action
  3. BedrockKBPromptBuilder Apex class calls the Bedrock Retrieve API
     via Named Credential (AWS Sig V4 signed request)
  4. Bedrock converts the query to a vector embedding and searches
     the Knowledge Base via OpenSearch Serverless
  5. The most relevant document chunks are returned to Salesforce
  6. Chunks are injected into the resolved Prompt Template and passed
     to the chosen LLM, which generates the final response
```

---

## Apex Classes

| Class | Purpose |
|---|---|
| `BedrockKBData` | JSON request/response data structures for both APIs |
| `BedrockKBService` | HTTP callout layer — `retrieve()` and `retrieveAndGenerate()` |
| `BedrockKBPromptBuilder` | `@InvocableMethod` for Prompt Template actions (Retrieve path) |
| `BedrockKBPromptBuilderSimple` | Lightweight version for quick testing |
| `BedrockKBAgentAction` | `@InvocableMethod` for Agentforce/Flow actions (RetrieveAndGenerate path) |
| `BedrockKBServiceTest` | Apex test class with mock HTTP responses |

---

## Prerequisites

- Salesforce org with Agentforce enabled
- Salesforce CLI (`sf`) installed: https://developer.salesforce.com/tools/salesforcecli
- AWS account with access to Amazon Bedrock
- An existing Bedrock Knowledge Base with at least one synced data source

---

## Setup

### Step 1 — AWS: Create the Knowledge Base

1. In the AWS Console, go to **Amazon Bedrock → Knowledge bases → Create knowledge base**
2. Configure a data source (S3 bucket with your documents)
3. Choose an embedding model (e.g. `amazon.titan-embed-text-v1`)
4. Choose a vector store (OpenSearch Serverless recommended)
5. Run the initial sync and wait for **Sync complete**
6. Note the **Knowledge Base ID** (10-character alphanumeric string)

### Step 2 — AWS: Enable model access

1. Go to **Amazon Bedrock → Model catalog**
2. Request access for the model you intend to use for generation
3. Wait until status shows **Access granted**
4. Note the **inference profile ARN** for your chosen model  
   (found under **Bedrock → Inference profiles**)

### Step 3 — AWS: Create the IAM user and policy

1. Copy `iam-policy.json` and replace all `YOUR_*` placeholders with your actual values:
   - `YOUR_REGION` — e.g. `us-east-2`
   - `YOUR_ACCOUNT_ID` — 12-digit AWS account ID
   - `YOUR_KNOWLEDGE_BASE_ID` — from Step 1

2. In the AWS Console go to **IAM → Policies → Create Policy**  
   Paste the updated JSON and name the policy (e.g. `BedrockKnowledgeBasePolicy`)

3. Go to **IAM → Users → Create user**  
   Name: `salesforce-bedrock-integration`  
   Attach the policy created above

4. Open the new user → **Security credentials → Create access key**  
   Use case: **Third-party service**  
   **Save the Access Key ID and Secret Access Key** — the secret is shown only once

### Step 4 — Update Apex configuration

Before deploying, update two files with your AWS values:

**`force-app/main/default/classes/BedrockKBService.cls` — line 17**
```apex
private static final String KNOWLEDGE_BASE_ID = 'YOUR_KNOWLEDGE_BASE_ID';
```
Replace `YOUR_KNOWLEDGE_BASE_ID` with the ID from Step 1.

**`force-app/main/default/classes/BedrockKBData.cls` — line 93**
```apex
this.modelArn = 'arn:aws:bedrock:YOUR_REGION:YOUR_ACCOUNT_ID:inference-profile/YOUR_INFERENCE_PROFILE_ID';
```
Replace with the full inference profile ARN from Step 2.

### Step 5 — Deploy to Salesforce

```bash
# Authenticate to your org if not already done
sf org login web --alias myOrg

# Deploy all Apex classes
sf project deploy start --source-dir force-app --target-org myOrg

# Run tests to verify
sf apex run test --class-names BedrockKBServiceTest --target-org myOrg --result-format human
```

### Step 6 — Configure Salesforce Named Credentials

The Named Credential and External Credential must be created through the Salesforce Setup UI because AWS access keys cannot be stored in deployable metadata.

**External Credential**  
Setup → Named Credentials → External Credentials → New

| Field | Value |
|---|---|
| Label | `AWS Bedrock` |
| Name | `AWS_Bedrock` |
| Authentication Protocol | AWS Signature Version 4 |
| AWS Region | your region (e.g. `us-east-2`) |
| AWS Service | `bedrock-agent-runtime` |

Add a **Principal**:
- Principal Type: Named Principal
- Principal Name: `default`
- AWS Access Key ID: *(from Step 3)*
- AWS Secret Access Key: *(from Step 3)*

**Named Credential**  
Setup → Named Credentials → New

| Field | Value |
|---|---|
| Label | `AWS Bedrock API` |
| Name | `AWS_Bedrock_API` |
| URL | `https://bedrock-agent-runtime.YOUR_REGION.amazonaws.com` |
| External Credential | `AWS Bedrock` |
| Generate Authorization Header | ✓ Enabled |

### Step 7 — Configure the Agentforce agent

1. **Create a Prompt Template** that references the KB context:
   - Add the **Get Bedrock KB Context** action (from `BedrockKBPromptBuilder`)
   - Reference the output in your template body as `{!$Apex.Get_Bedrock_KB_Context.Prompt}`

2. **Add the Prompt Template as an agent action** on the relevant topic of your Agentforce agent

3. Test by asking the agent a question that requires knowledge base content

---

## Testing

**Apex unit tests (mocked — no AWS calls):**
```bash
sf apex run test --class-names BedrockKBServiceTest --target-org myOrg --result-format human
```

**End-to-end smoke test (Execute Anonymous in Developer Console):**
```apex
BedrockKBData.RetrieveResponse r = BedrockKBService.retrieve('Your test question here', 3);
System.debug('Results: ' + r.retrievalResults.size());
System.debug('First chunk: ' + r.retrievalResults[0].content.text);
```

---

## Observability

**Salesforce — Agentforce Observability**
- Turn-by-turn conversation trace for every agent session
- Action invocation log — which actions fired, with inputs and outputs
- Prompt Template execution details and context injected
- Apex callout success/failure per session turn

**AWS — CloudWatch Logs**
- Real-time capture of every inbound query translated into a vector embedding
- Knowledge Base ingestion and sync operation logs
- IAM access events via CloudTrail
- API call volume and latency in CloudWatch Metrics

---

## Security notes

- AWS access keys are stored only in the Salesforce External Credential principal — never in code or version control
- The IAM policy follows least-privilege: only the permissions required for Knowledge Base access are granted
- No org-specific values (account IDs, KB IDs, keys) are present in this repository — all require explicit configuration before use
- Never commit `*.env` files or any file containing real credentials — both are covered by `.gitignore`

---

## Repo structure

```
.
├── force-app/
│   └── main/default/classes/
│       ├── BedrockKBData.cls                  # API data structures
│       ├── BedrockKBService.cls               # HTTP callout layer
│       ├── BedrockKBPromptBuilder.cls         # Prompt Template invocable
│       ├── BedrockKBPromptBuilderSimple.cls   # Lightweight test variant
│       ├── BedrockKBAgentAction.cls           # Agentforce/Flow invocable
│       └── BedrockKBServiceTest.cls           # Apex unit tests
├── iam-policy.json                            # IAM policy template (placeholders only)
├── sfdx-project.json
├── .forceignore
├── .gitignore
└── README.md
```
