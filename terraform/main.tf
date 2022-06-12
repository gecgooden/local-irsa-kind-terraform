data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "local-irsa-oidc" {
    bucket = "local-irsa-oidc-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

resource "aws_s3_object" "discovery" {
  bucket = aws_s3_bucket.local-irsa-oidc.id
  key = ".well-known/openid-configuration"

  acl = "public-read"
  content = jsonencode({
    "issuer": "https://${aws_s3_bucket.local-irsa-oidc.bucket_domain_name}/",
    "jwks_uri": "https://${aws_s3_bucket.local-irsa-oidc.bucket_domain_name}/keys.json",
    "authorization_endpoint": "urn:kubernetes:programmatic_authorization",
    "response_types_supported": [
        "id_token"
    ],
    "subject_types_supported": [
        "public"
    ],
    "id_token_signing_alg_values_supported": [
        "RS256"
    ],
    "claims_supported": [
        "sub",
        "iss"
    ]
  })
}

resource "tls_private_key" "oidc" {
    algorithm = "RSA"
}

resource "aws_s3_object" "keys" {
    bucket = aws_s3_bucket.local-irsa-oidc.id
    key = "keys.json"
    acl = "public-read"
    content = jsonencode({
        "keys": [tomap(data.external.generate-keys.result)]
    })
}

data "tls_certificate" "bucket_certificate" {
    url = "https://${aws_s3_bucket.local-irsa-oidc.bucket_domain_name}"
}

data "external" "generate-keys" {
    program = ["go", "run", "./main.go"]
    working_dir = "${path.module}/generate-keys"

    query = {
        public_key = tls_private_key.oidc.public_key_pem
    }
}

resource "aws_iam_openid_connect_provider" "local-irsa" {
    url = "https://${aws_s3_bucket.local-irsa-oidc.bucket_domain_name}"
    client_id_list = [
        "sts.amazonaws.com"
    ]
    thumbprint_list = data.tls_certificate.bucket_certificate.certificates.*.sha1_fingerprint
}

resource "aws_secretsmanager_secret" "public_key" {
   name = "local-oidc/public-key" 
}

resource "aws_secretsmanager_secret_version" "public_key_1" {
    secret_id = aws_secretsmanager_secret.public_key.id
    secret_string = tls_private_key.oidc.public_key_pem
}

resource "aws_secretsmanager_secret" "private_key" {
   name = "local-oidc/private-key" 
}

resource "aws_secretsmanager_secret_version" "private_key_1" {
    secret_id = aws_secretsmanager_secret.private_key.id
    secret_string = tls_private_key.oidc.private_key_pem
}

output "bucket_hostname" {
    value = aws_s3_bucket.local-irsa-oidc.bucket_domain_name
}

data "aws_iam_policy_document" "assume-policy" {
    statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test = "StringEquals"
      variable = "${aws_s3_bucket.local-irsa-oidc.bucket_domain_name}:sub"

      values = [
        "system:serviceaccount:default:example-sa"
      ]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.local-irsa.arn]
    }
  }
}

resource "aws_iam_role" "example-role" {
  name                = "example-role"
  path                = "/"
  assume_role_policy  = data.aws_iam_policy_document.assume-policy.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
}

output "iam-role" {
    value = aws_iam_role.example-role.arn
}