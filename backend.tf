terraform {
  backend "s3" {
    bucket         = "lambda-microservice-challenge"
    key            = "remote.tfstate"
    region         = "us-east-1"
    dynamodb_table = "s3-state-lock"
  }
}