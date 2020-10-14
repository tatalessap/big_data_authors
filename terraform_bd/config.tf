provider "aws" {
   profile                 = var.profile_name
   region                  = var.AWS_region
   shared_credentials_file = var.AWS_credentials_path
}

resource "aws_security_group" "sec_group" {
	name = "Terraform_sec_group"

        ingress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
        }

	ingress {
		from_port        = 0
		to_port          = 0
		protocol         = "-1"
		ipv6_cidr_blocks = ["::/0"]
	}

	ingress {
		from_port   = 22
		to_port     = 22
		protocol    = "6"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "tag-value"
  }
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.test_role.name}"
}


resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = "${aws_iam_role.test_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_instance" "master" {
	ami             = var.AMI_code
	instance_type   = var.instance_type
	key_name        = var.access_key_name
	iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
	security_groups = ["Terraform_sec_group"]
	depends_on      = [aws_security_group.sec_group]

	tags = {
		Name = "namenode"
	}

	connection {
		type        = "ssh"
		user        = "ubuntu"
		private_key = file(var.access_key_path)
		host        = self.public_dns
	}

	provisioner "local-exec" {
		command = "sleep 20 && scp -o StrictHostKeyChecking=no -i ${var.access_key_path} ${var.access_key_path} ubuntu@${self.public_dns}:/home/ubuntu/.ssh"
	}

	provisioner "remote-exec" {
		script = "./Scripts/master_script.sh"
	}
}

resource "aws_instance" "slave1" {
	ami             = var.AMI_code
	instance_type   = var.instance_type
	key_name        = var.access_key_name
	iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
	security_groups = ["Terraform_sec_group"]
	depends_on      = [aws_security_group.sec_group, aws_instance.master]

	tags = {
		Name = "datanode2"
	}

	connection {
		type        = "ssh"
		user        = "ubuntu"
		private_key = file(var.access_key_path)
		host        = self.public_dns
	}

	provisioner "local-exec" {
		command = "sleep 20"
	}

	provisioner "file" {
		source      = "./Scripts/slave_script.sh"
		destination = "/home/ubuntu/boot_script.sh"
	}

	provisioner "remote-exec" {
		inline = [
			"chmod 777 boot_script.sh",
			"./boot_script.sh ${aws_instance.master.public_dns}",
			"rm boot_script.sh"
		]
	}
}

resource "aws_instance" "slave2" {
	ami             = var.AMI_code
	instance_type   = var.instance_type
	key_name        = var.access_key_name
	iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
	security_groups = ["Terraform_sec_group"]
	depends_on      = [aws_security_group.sec_group, aws_instance.master]

	tags = {
		Name = "datanode3"
	}

	connection {
		type        = "ssh"
		user        = "ubuntu"
		private_key = file(var.access_key_path)
		host        = self.public_dns
	}

	provisioner "local-exec" {
		command = "sleep 20"
	}

	provisioner "file" {
		source      = "./Scripts/slave_script.sh"
		destination = "/home/ubuntu/boot_script.sh"
	}

	provisioner "remote-exec" {
		inline = [
			"chmod 777 boot_script.sh",
			"./boot_script.sh ${aws_instance.master.public_dns}",
			"rm boot_script.sh"
		]
	}
}
