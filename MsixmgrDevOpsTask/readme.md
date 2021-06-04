# MSIXMGR Custom Pipeline Task
This is a custom pipeline task that will do the following:
1. Create a temporary VM.
1. Download MSIXMGR tool to the VM.
1. Download MSIX packages from an Azure Blob Storage container.
1. Create a VHD, VHDX, or CIM using MSIXMGR.
1. Expand MSIX packages to the VHD, VHDX, or CIM.
1. Save the VHD, VHDX or CIM to an Azure Blob Storage container.
1. Delete the temporary VM.

# Requirements
* Azure Subscription
* Powershell 5.1 or Greater
* [Az Powershell Module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-6.0.0)
* [nodejs](https://nodejs.org/en/)
* [tfx-cli](https://github.com/Microsoft/tfs-cli)
    ```
    npm install tfx-cli -g
    ```

# Testing Locally
1. Update Test-MsixmgrTask.ps1 with correct parameters.
1. Run the following commands from powershell.
    ```powershell
    # Connect to your Azure subscription
    Connect-AzAccount -SubscriptionId "Your Subscription ID"

    # Run the pipeline task
    .\Test-MsixmgrTask.ps1
    ```
# Folder Structure
The breakdown of the folder structure is: 
* images - contains icon files
* MsixmgrTask - contains code for the DevOps task
* azure-pipelines-sample.yml - sample DevOps Pipeline
* Test-MsixmgrTask.ps1 - input file for local testing 
* vss-extensions.json - Publishing information 


# User Guide
1. Clone this repo to your local machine
2. Make sure to edit the vss-extension.json file to use your publisher and name.
4. Create a new package by running this command from the root directory:
    ```
    tfx extension create --manifest-globs vss-extension.json
    ```
5. Go to https://marketplace.visualstudio.com/manage/createpublisher?managePageRedirect=true and create a publisher. 
6. Click New Extension and in the drop down select Azure DevOps.
7. Upload the .vsix file generated from step 5. 
8. Once uploaded click the three dots next to your task and click on Share/Unshare. 
9. Enter the DevOps organization name you wish to share your task to. 
10. Login to your Azure DevOps organization as the owner and click organization settings in the bottom left. 
11. Go to Extensions in the left hand pane.
12. Select Shared and then install your task.
13. Once installed you can use the assistant when creating a pipeline to fill out and populate the variables or use the example pipeline. 