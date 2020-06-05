# powershell-o365-c2b-sync

## Synopsis
A couple of PowerShell scripts to mirror your Office 365 group and user structure to the [card2brain](https://card2brain.ch) web application.

## Requirements
* Office 365 corporate subscription
* card2brain corporate subscription with activated API
* [AzureADPreview](https://www.powershellgallery.com/packages/AzureADPreview) PowerShell module installed on the computer where you run the scripts. If you prefer to use the general release [AzureAD](https://www.powershellgallery.com/packages/AzureAD) module, adapt the Import-Module command in the *Include\C2b-AmAnfang-Template.ps1* script accordingly.

## Initial setup
* Follow the instruction steps 1 - 5 in the *Include\C2b-AmAnfang-Template.ps1* script.
* See the comments in the headers of the 3 main scripts in the root directory for how to run initial dummy tests with extended logging.

## Known issues
* Error handling is far from bulletproof.
* Delete / cleanup of card2brain users and groups that no longer exist in Office 365 is not yet implemented. You have to clean up zombies manually. (Note: UPN changes on existing users in Office 365 are correctly synched to card2brain. Same for group membership changes.)

## Disclaimer and license
* Use at your own risk.
* This work is governed by [The Unlicense](LICENSE).
