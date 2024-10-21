provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"  # Ensure this does not conflict with existing subnets
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"  # Ensure this does not conflict with existing subnets
  availability_zone = "${var.region}b"
}

resource "aws_security_group" "allow_http" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["124.123.184.23/32"] # Replace with your public IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

resource "aws_db_instance" "default" {
  allocated_storage     = 20
  engine               = "mysql"
  engine_version       = "8.0"  # Use the valid version you found
  instance_class       = "db.t3.micro"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.default.name
  skip_final_snapshot   = true
}


resource "aws_s3_bucket" "static_files" {
  bucket = "${var.environment}-opensupports-static"
  #acl    = "private" # or "public-read" if necessary

  tags = {
    Name = "${var.environment}-opensupports-static"
    Environment = var.environment
  }
}

# Optionally, add versioning to the bucket
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.static_files.bucket

  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "/aws/ec2/${var.environment}-app-logs"
  retention_in_days = 14  # Adjust retention as needed
  tags = {
    Environment = var.environment
  }
}
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.environment}-ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ec2_cloudwatch_policy" {
  name = "${var.environment}-ec2-cloudwatch-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = aws_iam_policy.ec2_cloudwatch_policy.arn
}

resource "aws_iam_instance_profile" "ec2_cloudwatch_instance_profile" {
  name = "${var.environment}-cloudwatch-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  iam_instance_profile   = aws_iam_instance_profile.ec2_cloudwatch_instance_profile.name

  monitoring = true  # Enable detailed monitoring

  tags = {
    Name = "${var.environment}-opensupports-app"
  }
}
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80  # Trigger alarm when CPU usage exceeds 80%
  alarm_actions       = [aws_sns_topic.alerts.arn]  # Replace with your SNS topic ARN for notifications
  dimensions = {
    InstanceId = aws_instance.app.id
  }
  tags = {
    Environment = var.environment
  }
}
resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = "${var.environment}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1  # Trigger alarm when the instance status check fails
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    InstanceId = aws_instance.app.id
  }
  tags = {
    Environment = var.environment
  }
}
resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-cloudwatch-alerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "vamsi.putchala1011@gmail.com"  # Replace with your email
}
