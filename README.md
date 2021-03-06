# lambda-ebs-delete

AWS lambda code (python) to delete aged, not in use volumes (expect if it has exclude tag).

## Table of contents

- [lambda-ebs-delete](#lambda-ebs-delete)
  - [Table of contents](#table-of-contents)
    - [High-level overview - Solution](#high-level-overview---solution)
      - [Dependencies - Python code](#dependencies---python-code)
      - [Dependencies - Permissions](#dependencies---permissions)
      - [Dependencies - Trigger](#dependencies---trigger)
    - [Implementation - With automation](#implementation---with-automation)
      - [Terraform resource graph](#terraform-resource-graph)
      - [Providers](#providers)
      - [Inputs](#inputs)
      - [Outputs](#outputs)
    - [Implementation - Manual](#implementation---manual)
      - [Create Role and Policy (IAM)](#create-role-and-policy-iam)
      - [Create Lambda function](#create-lambda-function)
      - [Set up trigger](#set-up-trigger)
    - [How to exclude specific volumes?](#how-to-exclude-specific-volumes)
  - [License](#license)
  - [Author Information](#author-information)

### High-level overview - Solution

![picture](Documentation/diagram.png)

The heart of the solution is a **python code executed by lambda** function. This code is responsible to:

- Check **all volumes**.
- Filter out **in-use volumes** (attached to an instance).
- Check the **age of volumes** (retention time).
- Check if the **volume has a specific tag**.
- **Delete** the volume(s).

The whole solution was created to AWS as cloud provider with AWS's self-services. It means this specific solution is applicable just for AWS.

#### Dependencies - Python code

- Tested with python **3.7** and **3.8**. Python script dependencies are in script (import).
- Lambda **Environment Variable**:
- - **`IGNORE_WINDOW`** --> Define the retention time, **in days**.

#### Dependencies - Permissions

As the code execute AWS API calls (boto), it needs specific **permission** to be able to do that. Responsible components:

- **Policy** --> Policy definition. It contains **what can be done by role**, where this policy was attached.
- **Role** --> It is like a "container". Role may have more than 1 policy attached. This will be attached to **lambda to be able to execute AWS services specific calls on behalf of role**.

#### Dependencies - Trigger

As this whole serverless solution's main goal to cleanup the affected AWS environment's region automatically, **code should run regularly**. To achieve this:

- **CloudWatch - CRON expression** --> Time-based expression with trigger purpose. **Schedule to start the lambda** function's execution.

### Implementation - With automation

This solution can be implemented via **terraform**, so in automatic way.

Feel free to implement it bi CI/CD tool like gitlab CICD or with Jenkins.


#### Terraform resource graph

![picture](Documentation/graph.svg)
#### Providers

| Name | Version |
|------|---------|
| archive | n/a |
| aws | ~> 3.23 |

#### Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| aws-lambda-function-memory | Maximum allowed memory for the lambda function in MB. | `number` | `"128"` |
| aws-lambda-function-timeout | Timeout after lambda function will exit. In sec(s) | `number` | `"60"` |
| aws-cloudwatch-event-rule-schedule-expression | Select runtime engine provided by lambda service. | `string` | `"cron(0 3 * * ? *)"` |
| aws-lambda-function-runtime | Select runtime engine provided by lambda service. | `string` | `"python3.8"` |
| profile | AWS Credential(s) profile. Define the name of the profile as defined in your aws credentials file. | `string` | `"default"` |
| region | AWS region. Where to deploy with this Infrastructure-As-A-Code - terraform. | `string` | `"us-east-1"` |
| shared\_credentials\_file | \*\*PRE-REQUIRED!\*\* Path of your AWS credentials file. Do NOT store it under version control system! | `string` | `"./secrets/credentials"` |

#### Outputs

| Name | Description |
|------|-------------|
| Lambda\_function | Lambda function's ARN. |
| account\_id | AWS account id, where you deployed infrastructure. |

### Implementation - Manual

Details about how you can implement the solution manually.

#### Create Role and Policy (IAM)

**Navigate in your AWS console to [IAM](https://console.aws.amazon.com/iam/home#/home).**

![picture](Documentation/IAM_1.png)

- Click to **"Roles"**.
- Click to **"Create Role"**.

**Create role like:**

![picture](Documentation/IAM_2.png)

- Choose **"Lambda"**.
- Click **"Next: Permissions"**.

**Create a new policy:**

![picture](Documentation/IAM_3.png)

- Click to **"Create policy"**.

Edit the Policy's content like:

![picture](Documentation/IAM_4.png)

- Click to **"JSON" tab**.
- **Paste** Policy content.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "cloudtrail:LookupEvents",
                "logs:CreateLogStream",
                "ec2:DescribeVolumeStatus",
                "cloudtrail:StartLogging",
                "ec2:DescribeVolumes",
                "cloudtrail:CreateTrail",
                "cloudtrail:GetTrailStatus",
                "ec2:DescribeVolumesModifications",
                "logs:CreateLogGroup",
                "logs:PutLogEvents",
                "ec2:DescribeVolumeAttribute",
                "cloudtrail:DescribeTrails"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "ec2:DeleteVolume",
            "Resource": "arn:aws:ec2:*:909993075274:volume/*"
        }
    ]
}
```

**Review policy:**

![picture](Documentation/IAM_5.png)

- Fill up the **name** field.
- Fill up **Description** section.
- Click to **"Crete policy"**.

**Now again, start to create new role:**

![picture](Documentation/IAM_1.png)

-Click to **Roles**.
Click to **Crete role**.

**Select previously created policy**:

![picture](Documentation/IAM_6.png)

- **Search** for **ebs** (Name of the policy).
- **Select** it.

Optionally **add any TAG**:

![picture](Documentation/IAM_7.png)

- It depends on you tagging logic.

**Review and name your new role:**

![picture](Documentation/IAM_8.png)

- Add a **name** to your role.
- Fill up **Description** section.
- Click to **Create role**.

#### Create Lambda function

Navigate to the **affected region**'s **Lambda** service && **Create a new function**:

![picture](Documentation/LAMBDA_1.png)

- Choose right **region**.
- Navigate to **Lambda**.
- **Create function**.

Provide **basic information** for lambda:

![picture](Documentation/LAMBDA_2.png)

- Leave on "**Author from scratch**".
- Fill up **name**.
- **Choose runtime** (**Python 3.8**, but tested with python 3.7 as well).
- **Open "Change default execution role"**.
- Choose "**Use an existing role**".
- From **dropdown** list ,select **previously created role** (ebs-delete-role).
- Click to **Create function**.

Copy **python code** to "Function code":

![picture](Documentation/LAMBDA_3.png)

- In **Function code section, copy the [python-ebs-delete.py](./lambda/python-ebs-delete.py) file's content** (file is in this repository).
- Don't left to **"Deploy"** the code. Click on it.

Add required **environment variable**:

![picture](Documentation/LAMBDA_4.png)

- Edit **Environment variables** section.
- Add `IGNORE_WINDOW`: Exclude not in use volumes which are older than (int) days.

Adjust **basic settings**:

![picture](Documentation/LAMBDA_5.png)

- Be sure, **Timeout** was set to **1 min**.
- Click to **Save**.

Create **test event** to test the code:

![picture](Documentation/LAMBDA_6.png)

- Click to **"Test"**.
- Add a **name** for your template test event ![picture](Documentation/LAMBDA_7.png)
- Click to **Create**.

As final step, **click to "Test"** (with your newly created test event), **but to be safe, you can comment out the following lines (with this modification code will not delete any volume, just print volumeIds)**:

```python
        #     for each_volume_id in flaggedAndnonpermanentVols:
        #         try:
        #             print("Deleting Volume with volume_id: " + each_volume_id)
        #             response = ec2.delete_volume(
        #                 VolumeId=each_volume_id
        #             )
        #         except Exception as e:
        #             print("Issue in deleting volume with id: " + each_volume_id + "and error is: " + str(e))
        # # waiters to verify deletion and keep alive deletion process until completed
        #     waiter = ec2.get_waiter('volume_deleted')
        #     waiter.config.max_attempts = 3
        #     try:
        #         waiter.wait(
        #             VolumeIds=flaggedAndnonpermanentVols,
        #         )
        #         print("Successfully deleted all volumes")
        #     except Exception as e:
        #         print("Error OR no any volume was flagged to delete:" + str(e))
```

- Click to Test. You should expect something similar:
  
![picture](Documentation/LAMBDA_8.png)

![picture](Documentation/LAMBDA_9.png)

#### Set up trigger

Trigger is responsible to fire up the lambda function. For this purpose Solution uses simple CRON expression to achieve time-based trigger.

**Add trigger:**

![picture](Documentation/TRIGGER_1.png)

- Click to trigger

**Configure trigger:**

![picture](Documentation/TRIGGER_2.png)

- Select **Create a new rule**.
- Add a **name** for your new rule.
- Provide a **Description**.
- Select **Schedule expression**.
- Fill up **Schedule expression** with : `cron(0 3 * * ? *)`
- Click to **Add**.

### How to exclude specific volumes?

If you would like to exclude specific volumes, you can simply add defined tag:value pair to it. Be noted, it is **case-sensitive!**.

![picture](Documentation/EXCLUDE.png)

- Add `Permanent` as TAG key.
- Add `YES` as TAG value.

## License

MIT

## Author Information

Peter Mikaczo - <petermikaczo@gmail.com>
