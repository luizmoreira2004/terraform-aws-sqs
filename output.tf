output "url_sqs" {
    value       = [
        {
            sqs = [
                for index, terraform_queue in aws_sqs_queue.terraform_queue :
                {
                    "sqs_name" : terraform_queue.name,
                    "sqs_url" : terraform_queue.url,
                    "sqs_access_key_user_consumo": aws_iam_access_key.user_consumo_access_key[index].id
                    "sqs_access_secret_key_user_consumo": join("", aws_iam_access_key.user_consumo_access_key[index].*.secret),
                    "sqs_access_key_user_envio": aws_iam_access_key.user_envio_access_key[index].id
                    "sqs_access_secret_key_user_envio": join("", aws_iam_access_key.user_envio_access_key[index].*.secret)
                }
            ]
        }
    ]   
    
    description = "output fila SQS"
    sensitive = true
}