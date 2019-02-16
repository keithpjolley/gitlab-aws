
# Added for consistancy. Not used
variable tags {}

resource "aws_iam_role" "nfs_server" {
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
}

resource "aws_iam_role_policy" "nfs_server_ebs" {
  role = "${aws_iam_role.nfs_server.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "nfs_server" {
  role = "${aws_iam_role.nfs_server.name}"
}

output "inst_prof_nfs_server" {
  value = "${aws_iam_instance_profile.nfs_server.id}"
}
