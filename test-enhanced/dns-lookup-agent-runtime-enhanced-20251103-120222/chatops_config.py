# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

ORIGINAL_VALUE = 0
TOP_RESOLUTION = 1

AWS_HEALTH_DASHBOARD_DURATION = 3

SLOT_CONFIG = {
    'action':               {'type': TOP_RESOLUTION, 'remember': True,  'error': 'I don\'t understand an action called "{}".'},
    'resource_identifier':  {'type': ORIGINAL_VALUE, 'remember': True},
    'resource_types':       {'type': ORIGINAL_VALUE, 'remember': True}
}

Q_AND_A_TOPICS = {
  "change server size":
      "To learn how to change a server size, check the document **(Atrium document TBA)**.",

  "login to an instance":
      "To learn how to login to an instance, check the document **[Cloud Tool User Guide](https://techtoc.thomsonreuters.com/non-functional/cloud-landing-zones/aws-cloud-landing-zones/command-line-access/user_guide/)** on the Atrium.",
    
  "contact ccoe":
      "To contact CCOE, please refer here **[Contact CCOE](https://trten.sharepoint.com/sites/intr-ihn-service-portfolio/SitePages/How-to-Get-IHN-Support.aspx)** on the Atrium.",

  "use the cloud tool":
      "Below are some of the cloud-tool usefull documents available in the Atrium." + "\n\n"
      "**[Cloud Tool User Guide](https://techtoc.thomsonreuters.com/non-functional/cloud-landing-zones/aws-cloud-landing-zones/command-line-access/user_guide/)**" + "\n\n"
      "**[Cloud Tool Connect to windows using RDP](https://trten.sharepoint.com/sites/intr-nuvola/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old%2FCloudtool%20to%20connect%20Windows%20instance%20using%20RDP%2Epdf&parent=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old)**" + "\n\n"
      "**[Cloud Tool SSH Tunneling - RDS, MySQL](https://trten.sharepoint.com/sites/intr-nuvola/SitePages/Cloud-tool-SSH-Tunneling-To-Connect-RDS---MySQL.aspx)**" + "\n\n"
      "**[Cloud Tool SSH Tunneling - RDS, MariaDB](https://trten.sharepoint.com/sites/intr-nuvola/SitePages/Cloud-tool-SSH-Tunneling-To-Connect-RDS---MariaDB.aspx)**" + "\n\n"
      "**[Cloud Tool SSH Tunneling - RDS, PostgreSQL](https://trten.sharepoint.com/sites/intr-nuvola/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old%2FCloudtool%20SSH%20Tunneling%20To%20Connect%20RDS%20%20PostgreSQL%2Epdf&parent=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old)**",
    
  "using cumulus":
      "Below are some of the useful links that will help you while working on cumulus" + "\n\n"
      "**[Blue/Green Resource Cleanup](https://trten.sharepoint.com/sites/intr-cumulus/SitePages/Blue-Green-Resource-Cleanup.aspx)**" + "\n\n"
      "**[Join cumulus MS teams Channel to get more help](https://teams.microsoft.com/l/message/19:c72f735f407a48f1902ad18ad14f1265@thread.skype/1624904859314?tenantId=62ccb864-6a1a-4b5d-8e1c-397dec1a8258&groupId=09374222-95d8-4cb6-bd1d-1bb9f8dfc625&parentMessageId=1624904424187&teamName=Project%20Cumulus&channelName=General&createdTime=1624904859314)**",

  "use VDI for cloud access":
      "To learn how to use VDI for cloud access, check the document **[Using VDI for Cloud Connectivity](https://trten.sharepoint.com/sites/intr-nuvola/SitePages/VDI-access-to-the-AWS-Cloud.aspx)** on the Atrium.",

  "reset my password":
      "To reset your password in TEN Domain, Go to this URL **[Password Reset](https://pwreset.thomsonreuters.com/ui)**.",

  "login to EC2":
      "To learn how to login to EC2, check the document **[Accessing EC2 using Cloud Tool](https://trten.sharepoint.com/sites/intr-nuvola/SitePages/Create-a-Simple-EC2-Instance-That-Can-be-Accessed-Using-cloud-tool(1).aspx)** on the Atrium.",

  "escalate a request":
      "To learn how to escalate a request, check the document **[IHN Contact & Escalation](https://trten.sharepoint.com/sites/intr-ihn-service-portfolio/SitePages/IHN-Contact-%26-Escalation(1).aspx)** on the Atrium.",

  "get access to aws":
      "To learn how to access an AWS account, check the document **[Getting Access to AWS](https://trten.sharepoint.com/sites/intr-nuvola/SitePages/AWS--Getting-Started(1).aspx?xsdata=MDN8MDF8fGIzOWNkYjBjODkwMTQxMjZhNTNiMWQ2Y2Y5OTdkODBmfDYyY2NiODY0NmExYTRiNWQ4ZTFjMzk3ZGVjMWE4MjU4fDF8MHw2Mzc3ODcxNTIxNzkxMjM5NzN8R29vZHxWR1ZoYlhOVFpXTjFjbWwwZVZObGNuWnBZMlY4ZXlKV0lqb2lNQzR3TGpBd01EQWlMQ0pRSWpvaVYybHVNeklpTENKQlRpSTZJazkwYUdWeUlpd2lWMVFpT2pFeGZRPT0%3D&sdata=djlaL0JNUCtNaCtmTndjeEo4QjRieHBOLzd5YkNuVHlWWWk4SFhsL2dTMD0%3D&ovuser=62ccb864-6a1a-4b5d-8e1c-397dec1a8258%2Ctharunkumar.holiga%40thomsonreuters.com&OR=Teams-HL&CT=1643125073336)** on the Atrium.",

  "create a data center project":
      "To learn how to create a data center project, check the document **[IaaS- Request New Data Center Project](https://trten.sharepoint.com/sites/intr-ihn-service-portfolio/SitePages/Request-New-Data-Center-Project-Reference-Guide.aspx)** on the Atrium.",

  "cloud application CIs":
      "To learn how about cloud configuration items, check the document **[Cloud Ready Support Model - ITSM](https://trten.sharepoint.com/sites/intr-ihn-service-portfolio/SitePages/Cloud-Ready-Support-Model---ITSM.aspx)** on the Atrium.",

  "get cloud team support":
      "To learn how to get cloud team support, check the document **[Support from IHN Cloud Team](https://thomsonreuters.service-now.com/sp?id=sc_cat_item&sys_id=9ebe12f513120380f05c7e276144b091)** in ServiceNow.",

  "access mongodb database in ec2": 
      "To learn how to access MongoDB in EC2, see **[Cloud-tool SSH Tunneling To Connect MongoDB Ec2 Instance in AWS](https://trten.sharepoint.com/sites/intr-nuvola/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old%2FCloudtool%20SSH%20Tunneling%20To%20Connect%20MongoDB%20Ec2%20Instance%20in%20AWS%2Epdf&parent=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old)** on the Atrium.",

  "access mariadb in aws":          
      "To learn how to access MariaDB in AWS, see **[Cloud-tool SSH Tunneling To Connect RDS - MariaDB](https://trten.sharepoint.com/sites/intr-nuvola/SitePages/Cloud-tool-SSH-Tunneling-To-Connect-RDS---MariaDB.aspx)** on the Atrium.",

  "access mysql in aws":            
      "To learn how to access MySQL in AWS, see **[Cloud-tool SSH Tunneling To Connect RDS - MySQL](https://trten.sharepoint.com/sites/intr-nuvola/SitePages/Cloud-tool-SSH-Tunneling-To-Connect-RDS---MySQL.aspx)** on the Atrium.",

  "access postgresql in aws":       
      "To learn how to access PostgreSQL in AWS, see **[Cloud-tool SSH Tunneling To Connect RDS - PostgreSQL](https://trten.sharepoint.com/sites/intr-nuvola/Shared%20Documents/Forms/AllItems.aspx?id=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old%2FCloudtool%20SSH%20Tunneling%20To%20Connect%20RDS%20%20PostgreSQL%2Epdf&parent=%2Fsites%2Fintr%2Dnuvola%2FShared%20Documents%2FNuvola%20Content%20Old)** on the Atrium.",

  "check my M account password":    
      "I can't show your password but you can go here => **[the Password Vault](https://pam.int.thomsonreuters.com/PasswordVault/v10)** to retrieve it, pls reach out to GSD if you don't see here."
}

KEYWORD_TOPICS = {
    "cloud tool":   "use the cloud tool",
    "VDI":          "use VDI for cloud access",
    "escalate":     "escalate a request",
    "support":      "get cloud team support",
    "cumulus":      "using cumulus"
}

class SlotError(Exception):
    pass
