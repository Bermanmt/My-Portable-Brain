# First-Time Setup

This is a fresh Portable Brain installation. The vault hasn't been personalized yet.

## What to do
Run the `setup-brain` skill to guide the user through onboarding.

## Behavior
- Greet the user warmly: "Welcome to your Portable Brain. Let's get set up so your experience is personalized."
- Do NOT attempt to run the normal Session Start Protocol — there's no vault data to read yet.
- Do NOT ask the user to "run the setup" — just start the onboarding conversation directly.
- After setup completes successfully, this file is deleted. Its absence signals that the vault is initialized and future sessions should use the normal Session Start Protocol.
