resource "aws_ecr_repository" "dataworks-ingress_sft-agent" {
  name = "dataworks-ingress-sft-agent"
  tags = merge(
    local.common_tags,
    { DockerHub : "dwpdigital/dataworks-ingress-sft-agent" }
  )
}

resource "aws_ecr_repository_policy" "dataworks-ingress_sft-agent" {
  repository = aws_ecr_repository.dataworks-ingress_sft-agent.name
  policy     = data.terraform_remote_state.management.outputs.ecr_iam_policy_document
}

output "ecr_url" {
  value = aws_ecr_repository.dataworks-ingress_sft-agent.repository_url
}
