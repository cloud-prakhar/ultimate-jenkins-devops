output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.jenkins.id
}

output "public_ip" {
  description = "Public IP for less-secure fallback access patterns."
  value       = aws_instance.jenkins.public_ip
}

output "ssm_port_forward_command" {
  description = "Command to port forward local 8080 to remote 8080."
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"8080\"],\"localPortNumber\":[\"8080\"]}'"
}
