from datetime import datetime, timedelta 
import os, os.path, sys
import boto3

def getAvailableVolumes(rgn):
    # returns list of volumes in 'available' state
    ec2 = boto3.client('ec2', region_name=rgn)
    availableVolList = []
    filterList = [{'Name': 'status', 'Values': ['available']}]
    response = ec2.describe_volumes(Filters=filterList, MaxResults=500)
    for v in response['Volumes']:
        availableVolList.append(v['VolumeId'])
    while('NextToken' in response):
        response = ec2.describe_volumes(Filters=filterList, MaxResults=500, NextToken=response['NextToken'])
        for v in response['Volumes']:
            availableVolList.append(v['VolumeId'])
    return availableVolList

def getNonpermanentVolumes(rgn):
     # returns list of volumes in 'nonpermanent' state
    ec2 = boto3.client('ec2', region_name=rgn)
    nonPermanentList = []
    filterList = [{'Name': 'tag:Permanent', 'Values': ['YES']}]
    response = ec2.describe_volumes(Filters=filterList, MaxResults=500)
    for v in response['Volumes']: 
        nonPermanentList.append(v['VolumeId'])
    while('NextToken' in response):
        response = ec2.describe_volumes(Filters=filterList, MaxResults=500, NextToken=response['NextToken'])
        for v in response['Volumes']:
            nonPermanentList.append(v['VolumeId'])
    return nonPermanentList

def getCloudTrailEvents(startDateTime, rgn):
    # gets CloudTrail events from startDateTime until "now"
    cloudTrail = boto3.client('cloudtrail', region_name=rgn)
    attrList = [{'AttributeKey': 'ResourceType', 'AttributeValue': 'AWS::EC2::Volume'}]
    eventList = []
    response = cloudTrail.lookup_events(LookupAttributes=attrList, StartTime=startDateTime, MaxResults=50)
    eventList += response['Events']
    while('NextToken' in response):
        response = cloudTrail.lookup_events(LookupAttributes=attrList, StartTime=startDateTime, MaxResults=50, NextToken=response['NextToken'])
        eventList += response['Events']
    return eventList

def getRecentActiveVolumes(events):
    # parses volumes from list of events from CloudTrail
    recentActiveVolumeList = []
    for e in events:
        for i in e['Resources']:
            if i['ResourceType'] == 'AWS::EC2::Volume':
                recentActiveVolumeList.append(i['ResourceName'])
    recentActiveVolumeSet = set(recentActiveVolumeList) # remove duplicates
    return recentActiveVolumeSet

def identifyAgedVolumes(availableVolList, activeVolList):
    # remove and return EBS volumes which are recently active from the list of available volumes
    if len(availableVolList) == 0:
        return None
    else:
        agedVolumes = list(set(availableVolList) - set(activeVolList))
        return agedVolumes

def identifyNonpermanentVolumes(agedVolumes, nonPermanentList):
    if len(agedVolumes) == 0:
        return None
    else:
        NonpermanentVolumes = list(set(agedVolumes) - set(nonPermanentList))
        return NonpermanentVolumes

def validateEnvironmentVariables():
    if(int(os.environ["IGNORE_WINDOW"]) < 1 or int(os.environ["IGNORE_WINDOW"]) > 90):
        print("Invalid value provided for IGNORE_WINDOW. Please choose a value between 1 day and 90 days.")
        raise ValueError('Bad IGNORE_WINDOW value provided')

def lambda_handler(event, context):
    rgn = os.environ["AWS_REGION"]
    try:
        validateEnvironmentVariables()
    except ValueError as vErr:
        print(vErr)
        sys.exit(1)
    print("boto3 version:"+boto3.__version__)
    startDateTime = datetime.today() - timedelta(int(os.environ["IGNORE_WINDOW"]))
    eventList = getCloudTrailEvents(startDateTime, rgn)
    activeVols = getRecentActiveVolumes(eventList)
    availableVols = getAvailableVolumes(rgn)
    flaggedVols = identifyAgedVolumes(availableVols, activeVols)
    if len(availableVols) == 0:
        print ("No any available volume. Nothing to do.")
        return None
    else:
        print ("All available volume:")
        print(availableVols)
        print ("All available, aged volume:")
        print (flaggedVols)
        if flaggedVols is None:
            print ("No any aged volume.")
            return None
        else:
            flaggedVols.sort()
            nonPermanentList = getNonpermanentVolumes(rgn)
            flaggedAndnonpermanentVols = identifyNonpermanentVolumes(flaggedVols, nonPermanentList)
            print ("All volume Named as EXCLUDE_VALUE:")
            print (nonPermanentList)
            print ("Volumes will be deleted:")
            print(flaggedAndnonpermanentVols)
            if flaggedAndnonpermanentVols is None:
                print ("Nothing to delete.")
                return None
            else:
                flaggedAndnonpermanentVols
                ec2 = boto3.client('ec2', region_name=rgn)
                for each_volume_id in flaggedAndnonpermanentVols:
                    try:
                        print("Deleting Volume with volume_id: " + each_volume_id)
                        response = ec2.delete_volume(
                            VolumeId=each_volume_id
                        )
                    except Exception as e:
                        print("Issue in deleting volume with id: " + each_volume_id + "and error is: " + str(e))
            # waiters to verify deletion and keep alive deletion process until completed
                waiter = ec2.get_waiter('volume_deleted')
                waiter.config.max_attempts = 3
                try:
                    waiter.wait(
                        VolumeIds=flaggedAndnonpermanentVols,
                    )
                    print("Successfully deleted all volumes")
                except Exception as e:
                    print("Error OR no any volume was flagged to delete:" + str(e))