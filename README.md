# streaming-analytics\


```
AMP_ENDPOINT=${module.cluster.amp_endpoint}

CARTS_DYNAMODB_TABLENAME=${module.cluster.cart_dynamodb_table_name}
CARTS_IAM_ROLE=${try(module.cluster.cart_iam_role, "")}
CATALOG_RDS_ENDPOINT=${module.cluster.catalog_rds_endpoint}
CATALOG_RDS_USERNAME=${module.cluster.catalog_rds_master_username}
CATALOG_RDS_PASSWORD=${base64encode(module.cluster.catalog_rds_master_password)}
CATALOG_RDS_DATABASE_NAME=${module.cluster.catalog_rds_database_name}
CATALOG_RDS_SG_ID=${module.cluster.catalog_rds_sg_id}
CATALOG_SG_ID=${module.cluster.catalog_sg_id}


GITOPS_IAM_SSH_KEY_ID=${try(module.cluster.gitops_iam_ssh_key_id, "")}
GITOPS_IAM_SSH_USER=${module.cluster.gitops_ssh_iam_user}
GITOPS_SSH_SSM_NAME=${module.cluster.gitops_ssh_ssm_name}
```