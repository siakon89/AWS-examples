# SES Email Identity (if you need to verify a new email address)
resource "aws_ses_email_identity" "sender" {
  email = local.sender_email
}
