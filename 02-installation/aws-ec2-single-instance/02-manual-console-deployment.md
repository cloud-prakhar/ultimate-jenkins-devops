# 02 - Manual Console Deployment

## Goal

Launch Jenkins manually from the AWS Console for live teaching where you want learners to see each click and security decision.

## Steps

1. Open the EC2 console and select your AWS region.
2. Launch a new instance.
3. Select Ubuntu Server 24.04 LTS from the Canonical listing.
4. Choose an instance type with at least 4 GB RAM such as `t3.large`.
5. Use or create an IAM role with:
   - `AmazonSSMManagedInstanceCore`
   - `CloudWatchAgentServerPolicy` optionally
6. Do not open SSH to the internet.
7. Do not open Jenkins `8080` to the internet.
8. Set root volume size to 50 GB or larger.
9. Paste [cloud-init/install-jenkins.sh](./cloud-init/install-jenkins.sh) into user data if you want automated installation.
10. Launch the instance.

## Expected Result

- the instance appears in EC2
- Systems Manager shows the instance as managed
- user data installs Java 21 and Jenkins LTS

## Less Secure Fallback

If Session Manager is unavailable for a demo emergency, open:

- TCP `8080` from `YOUR_PUBLIC_IP/32`

Remove that rule during cleanup.
