def copy_app_ami(dest_client, dest_region):
    """
    Copies our Gitlab Application Server image into this region if it's not already here.
    Ugh - I can't make these images public. That limits the usefulness of this strategy.
    """
    dest_response = dest_client.describe_images(Filters=[
            {'Name': 'tag:Ancestor-AMI-ID',  'Values': ['ami-074dd773b8f28df28']},
            {'Name': 'owner-id', 'Values': [GITHUB_APP_SERVER_OWNER_ID]}
        ])
    # This, the 
    # {'Name': 'image-id', 'Values': [GITHUB_APP_SERVER_AMI_ID]},

    if 'Images' not in dest_response:
        inform("Unknown problem finding Gitlab Application AMIs. Will try to press-on.")
        return False
    
    if len(dest_response['Images']):
        inform("Gitlab Application AMIs already populated in '{}'.")
        return True

    inform("Copying Gitlab Application AMI from '{}' to '{}'.".format(
                GITHUB_APP_SERVER_REGION, dest_region))

    source_profile = get_profile(PROFILES, GITHUB_APP_SERVER_REGION)
    source_client = get_ec2('client', profile, GITHUB_APP_SERVER_REGION)
    source_response = source_client.describe_images(Filters=[
            {'Name': 'image-id', 'Values': [GITHUB_APP_SERVER_AMI_ID]},
            {'Name': 'owner-id', 'Values': [GITHUB_APP_SERVER_OWNER_ID]}
        ])

    if 'Images' not in source_response:
        inform("Unknown problem finding original Gitlab Application AMI. Will try to press-on.")
        return False
   
    if not len(source_response['Images']):
        inform("No Gitlab Application AMIs returned. Will try to press-on.")
        return False

    # I'm not sure what to do about more than a single image. A problem for
    # a different day.
    source_image = source_response['Images'][0]
   
    # AWS tags are odd one may say.
    if 'Tags' in source_image:
        # swap references from source to destination regions
        val_re = re.compile(GITHUB_APP_SERVER_REGION)
        tags = [{'Key': i['Key'], 'Value': val_re.sub(region, i['Value'])} for i in source_image['Tags']]

    name = source_response['Images']['Name'] if 'Name' in source_response['Images'] else "replicant-zero"
    description = source_response['Images']['Description'] if 'Description' in source_response['Images'] else "gitlab application ami"

    # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ec2.html#EC2.Client.copy_image
    # Description (string) -- A description for the new AMI in the destination region.
    # Name (string) -- [REQUIRED]   The name of the new AMI in the destination region.
    # SourceImageId (string) -- [REQUIRED] The ID of the AMI to copy.
    # SourceRegion (string) -- [REQUIRED] The name of the region that contains the AMI to copy.
    # returns: { 'ImageId': 'string' }  -- ImageId: The ID of the new AMI.

    response = dest_client.copy_image(
        SourceRegion = GITHUB_APP_SERVER_REGION,
        SourceImageId = GITHUB_APP_SERVER_AMI_ID,
        Name = name,
        Description = description
    )

    if 'ImageId' not in response:
        inform("Copying the Gitlab Application server to the new region didn't work. Will try to continue.")
        return False

    response = dest_client.create_tags(Resources=[response['ImageId']], Tags=tags)
    inform(
"""Copy complete and apparently successful. It may take several minutes before this
AMI becomes available - but that's OK because it's going to take us several minutes
before we need it.""")
    return True
