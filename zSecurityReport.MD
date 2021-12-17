NLL SECURITY REPORT 12/14/21

Following the release of the v2 contract a security expert (https://twitter.com/t_snark) reached out to us after identifying a potential vulnerability in the smart contract. At that time we escalated the severity of the potential issue and had several other security and solidity experts weigh in. We came to a consensus that the potential vulnerability was significant enough that it warranted taking necessary steps to pause the smart contract in order to ensure the safety of our communities funds. The safety of the community is always our number 1 priority and nothing is more paramount to the Not Larva Labs project.

We started a sprint to ensure that community fund woulds be secure, and that a tested and properly audited solution could be deployed. Originally we were given confidence that the audit was complete, however we did not receive, nor did we know that we were supposed to receive additional documentation that reported warnings or potential vulnerabilities. Our audit report was delivered to us via word of mouth by the individual who arranged and managed the security audit.

We released the contract based on being told by the individual who arranged the audit, informing us that it was a solid contract.
The following were steps then taken:

1. The solidity and security experts assisting with the resolution contributed to a consensus decision to temporarily take down the front end in order to prevent users from depositing additional funds into the smart contract.

2. A dummy ERC-721 contract was deployed, replacing the CryptoPhunksV2 contract. This rendered all interactions impossible, immediately removing any possibility of exploitation.

3. Then we crafted a second dummy NFT contract that allows for the AcceptBid transactions to fail but to not revert.
    [a]acceptBid would fail because safeTransferFrom will not work
    [b]Then we crafted a second dummy NFT contract that allows for withdrawBidForPhunk, to allow users to cancel active bids.
4. Users are now able to withdraw Bids from the front end of the marketplace, and the vulnerable functions of acceptingBid are still blocked from being called, so as to avoid any loss of funds remaining in the smart contract.

5. We added a reentrancy guard by recommendation of security experts as a best practice to eliminate vulnerabilities that could potentially affect all bid and sale functions. 
Special thanks to all of the engineers, security experts, testers and @t_snark, who earned a 3 Phunk bug bounty paid by @Calchulus for helping secure user’s funds. 

Together, we make the Phunk Pham stronger!

- Team @NotLarvaLabs
