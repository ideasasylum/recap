# Recap

A Ruby gem that generates summaries of GitHub pull requests and posts them to Slack. Features include:
- AI-powered PR summaries using Claude
- Slack integration with thread support
- Daily or weekly summaries
- Markdown output

## Installation

```bash
gem install recap
```

## Configuration

Copy `.env.example` to `.env` and set the following environment variables:

```bash
# Required: GitHub repository to fetch PRs from (e.g. "owner/repo")
GITHUB_REPO=owner/repo

# Required: GitHub API token with repo access
GITHUB_TOKEN=your_github_token_here

# Optional: Claude API key for AI-powered PR summaries
CLAUDE_API_KEY=your_claude_api_key_here

# Optional: Slack API token for posting messages
SLACK_API_TOKEN=your_slack_token_here
```

## Usage

### Command Line

```bash
# Generate daily summary to stdout
recap

# Generate weekly summary
recap --range weekly

# Send daily summary to Slack user
recap --slack-user "@username"

# Send weekly summary to Slack channel
recap --slack-user "#channel" --range weekly

# Save to specific file
recap --output prs.md
```

### Using just

If you have [just](https://github.com/casey/just) installed:

```bash
# Daily summary to Slack
just recap-slack-daily "@username"
just recap-slack-daily "#channel"

# Weekly summary to Slack
just recap-slack-weekly "@username"
just recap-slack-weekly "#channel"

# Save to file
just recap-slack-daily-save "@username"
just recap-slack-weekly-save "#channel"
```

## Output Format

- Default format is Markdown
- Summaries include PR title, author, and description
- If `CLAUDE_API_KEY` is set, includes AI-generated summary
- When posting to Slack:
  - Initial message shows date range
  - PR details are posted as thread replies
  - Links are properly formatted for Slack

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
