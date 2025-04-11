set dotenv-load

# List available commands
default:
    @just --list

# Run recap with default format (markdown)
recap:
    bundle exec bin/recap

# Run recap with RTF format (formatted document)
recap-rtf:
    bundle exec bin/recap --format rtf

# Run recap and save to a file (default: ./recaps/YYYY-MM-DD.md)
recap-save:
    bundle exec bin/recap --output

# Run recap with RTF format and save to a file (default: ./recaps/YYYY-MM-DD.rtf)
recap-rtf-save:
    bundle exec bin/recap --format rtf --output

# Run recap and save to a specific file
recap-save-to file:
    bundle exec bin/recap --output {{file}}

# Post daily recap to a Slack user (e.g. just recap-slack-daily @jamie) or channel (e.g. just recap-slack-daily "#dev")
recap-slack-daily target:
    bundle exec bin/recap --slack-user "{{target}}" --range daily

# Post weekly recap to a Slack user or channel
recap-slack-weekly target:
    bundle exec bin/recap --slack-user "{{target}}" --range weekly

# Post daily recap to a Slack user/channel and save to a file
recap-slack-daily-save target:
    bundle exec bin/recap --slack-user "{{target}}" --range daily --output

# Post weekly recap to a Slack user/channel and save to a file
recap-slack-weekly-save target:
    bundle exec bin/recap --slack-user "{{target}}" --range weekly --output

# Post recap to a Slack user (e.g. just recap-slack @jamie) or channel (e.g. just recap-slack "#dev")
recap-slack target:
    @just recap-slack-daily "{{target}}"

# Post recap to a Slack user/channel and save to a file
recap-slack-save target:
    @just recap-slack-daily-save "{{target}}"
