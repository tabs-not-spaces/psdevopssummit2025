# MSAL Authentication: Auth Ain't Hard (But it isn't easy either)

## Summary

It's 2025, and somehow, authentication is still a barrier to entry for many IT Pros looking to build tooling and automation for their workloads. Let's dive in and demystify the MSAL authentication world and learn how to leverage it in your PowerShell scripts to authenticate against Microsoft Graph, Azure, and more.

## Main Issue

MSAL - the Microsoft Authentication Library, is a second-class citizen in the PowerShell world. Unlike in languages such as Python, Javascript or .NET, Where writing authentication code can be as simple as a few lines, Using PowerShell makes you make some tricky decisions. 

- How do you want to consume the MSAL library?
- Are you mainly making calls to Graph? Use the Microsoft.Graph.* Modules.
- Are you mainly working with Azure? Use the Az.* Modules.

Maybe that doesn't seem like a big deal, but it is. The underlying authentication library is technically the same both both of these modules... kind of... 

The Microsoft.Graph modules are built on top of the MSAL libraries directly, whereas the Az modules are built on top of the Azure.Identity library, which is a wrapper around MSAL.
Where this becomes a problem is when you want to use both modules in the same script - or profile.
PowerShell has a problem with loading multiple versions of the same assembly. This means that if you load the Az module, and then try to load the Microsoft.Graph module, it will fail with a "Cannot load assembly" error.
This is a problem, because the Az.* and Microsoft.Graph.* modules are maintained by different teams, and just by the nature of this, they can't always be in sync with each other.

## Solution?

What is the solution? We need a FIRST CLASS MSAL module for PowerShell that ALL other modules can inherit their authentication flows from.
This isn't a novel concept - all other languages do this. The MSAL library is a first class citizen in the .NET world, and it should be in PowerShell as well.
We almost had this with the MSAL.PS module, but while it was written by someone at Microsoft, it was never officially supported and has since been abandoned.
Solutions exist currently to support loading multiple assembly versions - specifically by leveraging Assembly Load Contexts, but this generally means that the module(s) with the conflicting assemblies need to be refactored to support this, which is a non-trivial task.

Justin Grote has spoken about custom ALCs in the past, and I know there's some sessions coming up this year at other PowerShell conferences that will cover this topic, but it falls out of scope in today's session.

More reading here: https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/resolving-dependency-conflicts?view=powershell-7.5

The community COULD provide a solution, but if it's not supported by Microsoft, it wont be used by Microsoft, and therefore it won't be used by the community.

## The Reality

So what do we do? Well, if we can't rely on a first-class MSAL module, we need to understand how the library works, so we can write our own authentication code and stop the reliance on "BIG DEPENDENCIES" for our solutions.

Even if somehow this problem is solved (either we get a first party auth module and all SDKs take on dependencies on it, or libraries are rewritten to overcome the assembly loading issues), knowing how authentication to Azure and Graph works is a valuable skill to have - not only for bragging rights, but also to be able to write lightweight cloud native solutions that start faster and use less resources.

## The plan

- Compare how auth looks using MSAL vs Azure.Identity vs Microsoft.Graph vs NoDependencies
- Show off the following flows
  - Auth Code Flow
  - Device Code Flow
  - Client Secret Flow
  - Managed Identity Flow