# frozen_string_literal: true

require_relative "recap/version"
require "octokit"
require "time"
require "anthropic"
require "optparse"
require "fileutils"
require "rrtf"
require "slack-ruby-client"

module Recap
  class Error < StandardError; end

  class PullRequest
    attr_reader :number, :title, :author, :author_name, :url, :merged_at, :description, :linear_details, :summary

    def initialize(number:, title:, author:, author_name:, url:, merged_at:, description:, linear_details: nil)
      @number = number
      @title = title
      @author = author
      @author_name = author_name
      @url = url
      @merged_at = merged_at
      @description = description
      @linear_details = linear_details
      @summary = nil
    end

    def generate_summary
      return @summary if @summary

      text_to_summarize = []
      text_to_summarize << "PR Description:\n#{description}" if description && !description.empty?
      text_to_summarize << "Linear Details:\n#{linear_details}" if linear_details

      return nil if text_to_summarize.empty?

      @summary = Summarizer.summarize(text_to_summarize.join("\n\n"), author_name || author)
    end

    def to_s(format = :markdown)
      clean_title = title.gsub(/\[.*?\]\s*/, "")
      output = []

      case format
      when :markdown
        output << "[#{clean_title}](#{url})"
      when :rtf
        output << "#{clean_title} (#{url})"
      end

      output << summary if summary
      output.join("\n")
    end

    def to_slack_block
      clean_title = title.gsub(/\[.*?\]\s*/, "")

      # Create a single section with both title and summary
      text = "• <#{url}|#{clean_title}>"
      text += "\n#{summary}" if summary

      [{
        type: "section",
        text: {
          type: "mrkdwn",
          text: text
        }
      }]
    end

    def to_rtf(doc)
      clean_title = title.gsub(/\[.*?\]\s*/, "")

      # Title with URL as a hyperlink
      doc.paragraph do |p|
        p.apply("bold" => true) do |b|
          b << clean_title
        end
        p << " ("
        p.apply(
          "foreground_color" => "#0366d6",
          "underline" => "SINGLE",
          "underline_color" => "#0366d6"
        ) do |link|
          link.link(url, url)
        end
        p << ")"
      end

      # Summary in regular text
      if summary
        doc.paragraph do |p|
          p << summary
        end
      end

      # Add extra newline
      doc.paragraph
    end
  end

  class Summarizer
    def self.summarize(text, author)
      client = Anthropic::Client.new(
        access_token: ENV["CLAUDE_API_KEY"],
        log_errors: true
      )

      system_prompt = "You are an expert at summarizing technical pull requests. Create a single bullet point that starts with the author's name and describes what they did. Be concise but specific. Format as '#{author} fixed/added/updated/etc...'"

      response = client.messages(
        parameters: {
          model: "claude-3-haiku-20240307",
          system: system_prompt,
          max_tokens: 200,
          messages: [
            {
              role: :user,
              content: "Summarize this pull request information into a single bullet point that starts with '#{author}' and describes what they did:\n\n#{text}"
            }
          ]
        }
      )

      response["content"][0]["text"].strip
    rescue => e
      puts "Warning: Failed to generate summary: #{e.message}"
      nil
    end
  end

  class CLI
    LINEAR_BOT_LOGIN = "linear[bot]"

    def self.run(args)
      new(args).run
    end

    def initialize(args)
      @args = args.dup
      @options = {
        format: :markdown,
        range: :daily  # Default to daily summary
      }
      parse_options
      @options[:output] ||= default_output_file

      unless ENV["GITHUB_REPO"]
        puts "Error: GITHUB_REPO environment variable is required"
        exit 1
      end

      setup_client
      setup_slack_client if @options[:slack_user]
    end

    def run
      prs = fetch_recent_prs
      prs.each do |pr|
        pr.generate_summary if ENV["CLAUDE_API_KEY"]
        if @options[:format] != :rtf
          puts pr.to_s(@options[:format])
          puts # Extra newline for separation
        end
      end

      if @options[:output]
        write_output(prs)
      elsif @options[:format] == :rtf
        write_rtf($stdout, prs)
      end

      if @options[:slack_user]
        post_to_slack(prs)
      end
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: recap [options]"

        opts.on("-f", "--format FORMAT", [:markdown, :rtf],
          "Output format (markdown or rtf)") do |format|
          @options[:format] = format
        end

        opts.on("-o", "--output [FILE]",
          "Output file (default: ./recaps/YYYY-MM-DD.{md,rtf})") do |file|
          @options[:output] = file
        end

        opts.on("--slack-user USER", "Send PR summary to Slack user (e.g. @username) or channel (e.g. #channel)") do |user|
          @options[:slack_user] = user
        end

        opts.on("-r", "--range RANGE", [:daily, :weekly],
          "Time range for PR summary (daily or weekly)") do |range|
          @options[:range] = range
        end

        opts.on("--help", "Show this help message") do
          puts opts
          exit
        end
      end.parse!(@args)
    end

    def default_output_file
      date = Time.now.strftime("%Y-%m-%d")
      ext = (@options[:format] == :rtf) ? "rtf" : "md"
      File.join("recaps", "#{date}.#{ext}")
    end

    def write_output(prs)
      FileUtils.mkdir_p(File.dirname(@options[:output]))

      case @options[:format]
      when :rtf
        File.open(@options[:output], "w") do |f|
          write_rtf(f, prs)
        end
      else
        content = prs.map { |pr| pr.to_s(@options[:format]) }.join("\n\n")
        File.write(@options[:output], content)
      end

      puts "\nOutput written to #{@options[:output]}"
    end

    def write_rtf(output, prs)
      doc = RRTF::Document.new
      doc.default_font = RRTF::Font.new(doc, "Arial")

      prs.each do |pr|
        pr.to_rtf(doc)
      end

      output.write(doc.to_rtf)
    end

    def setup_client
      token = ENV["GITHUB_TOKEN"]
      if token.nil? || token.empty?
        puts "Error: GITHUB_TOKEN environment variable is required"
        exit 1
      end

      @client = Octokit::Client.new(access_token: token)
    end

    def setup_slack_client
      token = ENV["SLACK_API_TOKEN"]
      if token.nil? || token.empty?
        puts "Error: SLACK_API_TOKEN environment variable is required"
        exit 1
      end

      Slack.configure do |config|
        config.token = token
      end

      @slack_client = Slack::Web::Client.new
    end

    def post_to_slack(prs)
      target = @options[:slack_user]

      # Determine if this is a channel or user
      if target.start_with?("#")
        # For channels, use the channel name as is
        channel = target
      else
        # For users, look up their ID (strip @ if present)
        username = target.sub(/^@/, "")
        response = @slack_client.users_list
        user = response.members.find { |m| m.name == username }

        if user.nil?
          puts "Error: Could not find Slack user '#{target}'"
          exit 1
        end

        channel = user.id
      end

      # First, post the header message
      days = @options[:range] == :weekly ? 7 : 1
      start_date = (Time.now - (days * 24 * 60 * 60)).strftime("%B %d, %Y")
      end_date = Time.now.strftime("%B %d, %Y")
      range_type = @options[:range].to_s.capitalize
      
      header_response = @slack_client.chat_postMessage(
        channel: channel,
        text: "#{range_type} PR Summary: #{start_date} to #{end_date}",
        as_user: true
      )

      # Then post the PR details as a thread
      blocks = [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "PR Details",
            emoji: true
          }
        }
      ]

      # Add each PR's blocks
      prs.each do |pr|
        blocks.concat(pr.to_slack_block)
      end

      # Post the message as a reply in the thread
      @slack_client.chat_postMessage(
        channel: channel,
        thread_ts: header_response.ts,
        blocks: blocks,
        text: "PR Details", # Fallback text for notifications
        as_user: true,
        unfurl_links: false # Keep the message compact
      )

      puts "\nSummary posted to Slack #{target}"
    rescue Slack::Web::Api::Errors::SlackError => e
      error_message = case e.message
      when "not_in_channel"
        "Error: Bot needs to be invited to the channel first. Please invite the bot to #{target} and try again."
      when "channel_not_found"
        "Error: Channel #{target} not found. Please check the channel name and try again."
      when "user_not_found"
        "Error: User #{target} not found. Please check the username and try again."
      else
        "Error posting to Slack: #{e.message}"
      end
      puts error_message
      exit 1
    end

    def fetch_recent_prs
      days = @options[:range] == :weekly ? 7 : 1
      start_time = (Time.now - (days * 24 * 60 * 60)).iso8601
      query = "repo:#{ENV["GITHUB_REPO"]} is:pr is:merged merged:>=#{start_time}"
      results = @client.search_issues(query)

      # Convert to PullRequest objects and sort by merge date
      prs = results.items.map { |pr| build_pull_request(pr) }
      prs.sort_by { |pr| pr.merged_at || Time.now }
    rescue Octokit::Unauthorized
      puts "Error: Invalid GitHub token"
      exit 1
    rescue Octokit::NotFound
      puts "Error: Repository not found or no access"
      exit 1
    end

    def build_pull_request(pr)
      full_pr = @client.pull_request(ENV["GITHUB_REPO"], pr.number)
      linear_details = fetch_linear_details(pr)

      # Fetch the author's name from their GitHub profile
      author_name = if pr.user.type == "Bot"
        pr.user.login # For bots, just use their login name
      else
        user = @client.user(pr.user.login)
        name = user.name || user.login
        # Extract first name (everything before the first space)
        name.split(" ").first
      end

      PullRequest.new(
        number: pr.number,
        title: pr.title,
        author: pr.user.login,
        author_name: author_name,
        url: pr.html_url,
        merged_at: pr.closed_at,
        description: full_pr.body,
        linear_details: linear_details
      )
    end

    def fetch_linear_details(pr)
      comments = @client.issue_comments(ENV["GITHUB_REPO"], pr.number)
      linear_comment = comments.find { |comment|
        comment.user.login == LINEAR_BOT_LOGIN && comment.user.type == "Bot"
      }
      linear_comment&.body
    end
  end
end
