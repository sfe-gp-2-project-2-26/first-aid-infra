output "instance_public_ip" {
  description = "Elastic IP of the production server"
  value       = aws_eip.medaid_eip.public_ip
}

output "ssh_command" {
  description = "SSH into the server"
  value       = "ssh -i deploy_key ubuntu@${aws_eip.medaid_eip.public_ip}"
}

output "application_url" {
  description = "Production URL"
  value       = "https://${var.domain_name}"
}

output "startup_logs" {
  description = "Command to tail the startup log on the server"
  value       = "ssh -i deploy_key ubuntu@${aws_eip.medaid_eip.public_ip} 'sudo tail -f /var/log/medaid-startup.log'"
}
