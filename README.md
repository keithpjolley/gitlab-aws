
# Bootstrap a GitLab Environment

## Introduction

This creates a stand-alone Gitlab environment in AWS. The goal was to make it
as simple as possible to bootstrap an entire environment from scratch.

## ;tldr -- recommended process

```
# Download this code into your home directory:
% git clone https://github.com/keithpjolley/gitlab-aws.git
% cd ~/gitlab-aws

# Create an AWS profile.
% ./bin/create


## Requirements

1. Linux or MacOS command line and internet access.
2. This source (https://github.com/keithpjolley/gitlab-aws).
3. Python with `boto3` installed (tested w/ Python3).
4. Assorted AWS access to for IAM, EBS, Route53, and EC2.

It's possible to run the entire setup from your existing host, however,
I recommend using a bootstrap host for two reasons. The first is because AWS commands
are  eager to find ways to get the access they need to run a command
successfully. This means you may specify one user but it will actually use
a default user or something from your $ENV. The second reason is that
the bootstrap host will provide a known environment with all the tools
already installed.

## Preinstallation

1) Create a new AWS user to run the rest of this installation from. You can
do it all from your existing accounts but I recommend creating a new user.

The username should reflect the purpose of the task so think along the lines
of `corp-gitlab` rather than `james-test-account`.

To create a new user with all required permissions run:
`$ ./bin/createuser username`

This will create a credentials file at `~/.aws/credentials_username`.

2) Create a bootstrap host.

This will build an ec2 host with all required tools installed.




1. Create a AWS IAM user named `install-gitlab`,  create a group with
the permissions that are that are in `additional/group-permission.json`,
and add this new account to the group.
https://console.aws.amazon.com/iam/home?region=us-west-1#/users

Select `Programmatic Access` only. Console access is not needed.

If you skip this step or create a different name without upd


2. Create security credentials for the new user and download them
to your local drive. You can add the new credentials to your existing
~/.aws/credentials file or keep them separate. In theory loading
them into your ENV will work too but I haven't tested that.

If you don't want to create a new user then your `default` profile
will be used. If you want to use a user name other than `install-gitlab`
or `default` then manually edit the username near the top of the
`bootstrap` file.

Save your new credentials in this format:

[install-gitlab]
aws_access_key_id = AKIA......
aws_secret_access_key = wxHx...........


# CREATE PEM FILE


3. Bring up an ec2 bootstrap host. Sharing AMIs across organizational
boundaries is inconvenient but bootstrapping this environment is just as
easy.

I used `CentOS 7 (x86_64) - with Updates HVM` on a t2.nano with no
additional options (8gb disk, ssh inbound only). Other flavors will
work but the directions for adding software will be trivially
different. Any region is acceptable.

I'll refer to the this host as `centos@ec2`, where `ec2` is the public
ip or dns of the new host.

4. Run the preinstall script:
`$ git clone git@github.com:keithpjolley/gitlab-aws.git`
`$ cd ./gitlab-aws`
`$ ssh -A centos@ec2 /bin/sh < ./bin/preinstall.sh`

5. Copy the credentials file to the new host. You don't need to copy
your existing credentials, like default.

Use the new credentials:
`    $ scp NEW_CREDENTIALS_FILE centos@ec2:.aws/credentials`
  Or:
`    $ scp ~/.aws/credentials centos@ec2:.aws/`

Login to the new host
`$ ssh centos@ec2`
`centos$ cd ./gitlab-aws`

Run the preins
`centos$ ./bootstrap.py region`
...
~13 minutes elapse...
...

The environment is now up and fully functional.

# To delete everything you just created don't use the AWS console!
`centos$ ./environment_region/terraform`
`centos$ terraform destroy --auto-approve`

This does a pretty good job of bringing everything down as long as you haven't
gone in and changed things around outside of terraform. If so, terraform gets
very confused and you can end up wasting quite a bit of time clicking through
the console trying to unravel dependencies.





# Setup the new machine sw requirements. Anaconda is probably overkill but 
# it makes it easies to get to the desired state
`$ ssh -A centos@ec2`
`$ sudo yum -y install git`

`$ git clone git@github.com:keithpjolley/gitlab-aws.git`
`$ cd gitlab-aws`
`$ sudo ./

