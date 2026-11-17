#!/usr/bin/env ruby
# frozen_string_literal: true

# gsna -- keep a set of git repositories in sync.
#
# Usage:
#   gsna [options] [REPOSITORY ...]
#
# Without repository arguments the list is read from `chezmoi data`
# (`data.git.syncfolders`).  Each repository is synchronized by:
#   1. committing local changes (including new files by default),
#   2. fetching the remote branch,
#   3. fast-forwarding, rebasing or pushing as needed.
#
# Only the Ruby standard library is used.

require "json"
require "open3"
require "optparse"
require "socket"

DEFAULT_RETRIES = 3
RETRY_DELAYS = [2, 4, 8].freeze

Options = Struct.new(:retries, :new_files, :quiet, :color, keyword_init: true)

class GsnaError < StandardError; end

class Reporter
  def initialize(quiet: false, color: false)
    @quiet = quiet
    @color = color
  end

  def section(text)
    puts "\n=== #{text} ===" unless @quiet
  end

  def info(text)
    puts text unless @quiet
  end

  def ok(text)
    puts paint(text, 32) unless @quiet
  end

  def warn(text)
    puts paint(text, 33) unless @quiet
  end

  def error(text)
    puts paint(text, 31)
  end

  def detail(text)
    puts text unless @quiet
  end

  private

  def paint(text, code)
    return text unless @color

    "\e[#{code}m#{text}\e[0m"
  end
end

def utf8(value)
  value.to_s.dup.force_encoding(Encoding::UTF_8).scrub
end

def git_environment
  {
    "GIT_TERMINAL_PROMPT" => "0",
    "GCM_INTERACTIVE" => "never"
  }
end

def run_git(dir, *args)
  out, err, status = Open3.capture3(git_environment, "git", "-C", dir.to_s, *args)
  [utf8(out), utf8(err), status]
rescue SystemCallError => e
  ["", "cannot run git: #{e.message}", nil]
end

def compact_output(out, err)
  text = err.to_s.strip
  text = out.to_s.strip if text.empty?
  text.lines.last(4).map(&:strip).reject(&:empty?).join("\n")
end

def git_config(dir, key)
  out, _err, status = run_git(dir, "config", "--get", key)
  return nil unless status&.success?

  value = out.strip
  value.empty? ? nil : value
end

def git_bool(dir, key)
  value = git_config(dir, key)
  return false if value.nil?

  %w[true 1 yes on].include?(value.downcase)
end

def with_retries(label, options, reporter)
  attempt = 0
  loop do
    attempt += 1
    out, err, status = yield
    return [out, err, status] if status&.success?

    detail = compact_output(out, err)
    if attempt <= options.retries
      delay = RETRY_DELAYS[attempt - 1] || RETRY_DELAYS.last
      reporter.warn("#{label} failed (attempt #{attempt}/#{options.retries + 1}): #{detail}")
      reporter.warn("retrying in #{delay}s...")
      sleep delay
    else
      reporter.error("#{label} failed after #{attempt} attempt(s): #{detail}")
      return [out, err, status]
    end
  end
end

def repository_state(dir)
  out, _err, status = run_git(dir, "rev-parse", "--git-dir")
  return "cannot locate the git directory" unless status&.success?

  git_dir = File.expand_path(out.strip, dir)
  {
    "rebase-merge" => "rebase in progress",
    "rebase-apply" => "rebase/am in progress",
    "MERGE_HEAD" => "merge in progress",
    "CHERRY_PICK_HEAD" => "cherry-pick in progress",
    "REVERT_HEAD" => "revert in progress",
    "sequencer" => "cherry-pick/revert in progress",
    "BISECT_LOG" => "bisect in progress"
  }.each do |marker, label|
    return label if File.exist?(File.join(git_dir, marker))
  end
  nil
end

def remote_for(dir, branch)
  configured = git_config(dir, "branch.#{branch}.pushRemote") ||
               git_config(dir, "remote.pushDefault") ||
               git_config(dir, "branch.#{branch}.remote")
  return configured if configured

  out, _err, status = run_git(dir, "remote")
  return nil unless status&.success?

  remotes = out.lines.map(&:strip).reject(&:empty?)
  return "origin" if remotes.include?("origin")
  return remotes.first if remotes.length == 1

  nil
end

def fetch_repo(dir, remote, branch, options, reporter)
  with_retries("git fetch #{remote}/#{branch}", options, reporter) do
    run_git(dir,
            "-c", "http.lowSpeedLimit=1000",
            "-c", "http.lowSpeedTime=30",
            "fetch", "--quiet", remote, branch)
  end
end

def push_repo(dir, remote, branch, options, reporter)
  _out, _err, status = with_retries("git push #{remote}/#{branch}", options, reporter) do
    run_git(dir,
            "-c", "http.lowSpeedLimit=1000",
            "-c", "http.lowSpeedTime=30",
            "push", "--quiet", remote, "#{branch}:#{branch}")
  end
  return false unless status&.success?

  reporter.ok("  pushed")
  true
end

def default_commit_message
  "changes from #{Socket.gethostname} on #{Time.now}"
end

def commit_local_changes(dir, branch, options, reporter)
  status_out, _err, status = run_git(dir, "status", "--porcelain")
  unless status&.success?
    reporter.error("  cannot read git status")
    return false
  end
  return true if status_out.empty?

  reporter.info("  working tree has changes")
  add_args = options.new_files ? ["add", "-A"] : ["add", "-u"]
  _out, add_err, add_status = run_git(dir, *add_args)
  unless add_status&.success?
    reporter.error("  git add failed: #{compact_output('', add_err)}")
    return false
  end

  _out, _err, diff_status = run_git(dir, "diff", "--cached", "--quiet")
  case diff_status&.exitstatus
  when 0
    # Nothing staged (for example, only ignored files or untracked files
    # when --no-new-files was requested).
    reporter.info("  nothing staged; leaving those changes alone")
  when 1
    reporter.info("  committing local changes...")
    message = git_config(dir, "branch.#{branch}.syncCommitMsg") || default_commit_message
    commit_args = ["commit", "-m", message]
    skip_hooks = git_bool(dir, "branch.#{branch}.syncSkipHooks") ||
                 git_bool(dir, "git-sync.syncSkipHooks")
    commit_args << "--no-verify" if skip_hooks
    _out, commit_err, commit_status = run_git(dir, *commit_args)
    unless commit_status&.success?
      reporter.error("  auto-commit failed: #{compact_output('', commit_err)}")
      return false
    end
    reporter.info("  committed: #{message}")
  else
    reporter.error("  cannot inspect staged changes")
    return false
  end

  if options.new_files
    remaining, _err, remaining_status = run_git(dir, "status", "--porcelain")
    unless remaining_status&.success?
      reporter.error("  cannot verify the working tree after auto-commit")
      return false
    end
    unless remaining.empty?
      reporter.error("  uncommitted changes remain after auto-commit:")
      reporter.detail(remaining.rstrip)
      return false
    end
  end

  true
end

def sync_repository(raw_path, source, options, reporter)
  path = if source == :data
           File.expand_path(raw_path, Dir.home)
         else
           File.expand_path(raw_path)
         end
  reporter.section("Syncing #{path}")

  unless File.directory?(path)
    reporter.error("  directory does not exist")
    return [path, :failed]
  end

  work_tree, _err, work_status = run_git(path, "rev-parse", "--is-inside-work-tree")
  unless work_status&.success? && work_tree.strip == "true"
    reporter.error("  not a git working tree")
    return [path, :failed]
  end

  bare, _err, bare_status = run_git(path, "rev-parse", "--is-bare-repository")
  if bare_status&.success? && bare.strip == "true"
    reporter.warn("  bare repository; skipping")
    return [path, :skipped]
  end

  state = repository_state(path)
  if state
    reporter.warn("  #{state}; skipping")
    return [path, :skipped]
  end

  branch_out, _err, branch_status = run_git(path, "symbolic-ref", "--quiet", "--short", "HEAD")
  unless branch_status&.success? && !branch_out.strip.empty?
    reporter.warn("  detached HEAD or no branch; skipping")
    return [path, :skipped]
  end
  branch = branch_out.strip

  remote = remote_for(path, branch)
  if remote.nil?
    reporter.error("  no configured remote (and no usable origin); skipping")
    return [path, :failed]
  end

  status_out, _err, status_status = run_git(path, "status", "--short")
  if status_status&.success? && !status_out.strip.empty?
    reporter.detail(status_out.rstrip)
  end

  return [path, :failed] unless commit_local_changes(path, branch, options, reporter)

  _out, _err, fetch_status = fetch_repo(path, remote, branch, options, reporter)
  return [path, :failed] unless fetch_status&.success?

  counts, count_err, count_status = run_git(path, "rev-list", "--count", "--left-right",
                                            "FETCH_HEAD...HEAD")
  unless count_status&.success?
    reporter.error("  cannot compare with #{remote}/#{branch}: #{compact_output('', count_err)}")
    return [path, :failed]
  end

  parts = counts.split
  unless parts.length == 2
    reporter.error("  unexpected output from git rev-list: #{counts.inspect}")
    return [path, :failed]
  end
  behind, ahead = parts.map(&:to_i)

  if behind.zero? && ahead.zero?
    reporter.ok("  already in sync")
  elsif behind.zero?
    reporter.info("  ahead by #{ahead}; pushing...")
    return [path, :failed] unless push_repo(path, remote, branch, options, reporter)
  elsif ahead.zero?
    reporter.info("  behind by #{behind}; fast-forwarding...")
    _out, merge_err, merge_status = run_git(path, "merge", "--ff", "--ff-only", "FETCH_HEAD")
    unless merge_status&.success?
      reporter.error("  fast-forward failed: #{compact_output('', merge_err)}")
      return [path, :failed]
    end
    reporter.ok("  fast-forwarded")
  else
    reporter.info("  diverged (ahead #{ahead}, behind #{behind}); rebasing...")
    _out, rebase_err, rebase_status = run_git(path, "rebase", "FETCH_HEAD")
    unless rebase_status&.success?
      reporter.error("  rebase failed: #{compact_output('', rebase_err)}")
      reporter.error("  resolve conflicts manually and run gsna again")
      return [path, :failed]
    end
    reporter.ok("  rebased")
    return [path, :failed] unless push_repo(path, remote, branch, options, reporter)
  end

  [path, :ok]
rescue StandardError => e
  reporter.error("  unexpected error: #{e.class}: #{e.message}")
  [path, :failed]
end

def folders_from_chezmoi
  command = ENV.fetch("GSNA_CHEZMOI", "chezmoi")
  out, err, status = Open3.capture3(command, "data", "--format", "json")
  unless status.success?
    raise GsnaError, "`#{command} data` failed: #{compact_output(out, err)}"
  end

  # chezmoi on Windows may start its JSON with a UTF-8 BOM.
  raw = utf8(out).sub(/\A\uFEFF/, "")
  data = JSON.parse(raw)
  raise GsnaError, "chezmoi data: expected a JSON object" unless data.is_a?(Hash)

  git_data = data["git"]
  folders = git_data.is_a?(Hash) ? git_data["syncfolders"] : nil
  return [] if folders.nil?
  raise GsnaError, "chezmoi data: git.syncfolders must be a list" unless folders.is_a?(Array)

  folders.map(&:to_s)
rescue SystemCallError => e
  raise GsnaError, "cannot run `#{command}`: #{e.message}"
rescue JSON::ParserError => e
  raise GsnaError, "cannot parse `#{command} data` output: #{e.message}"
end

def expand_repositories(paths, source)
  seen = {}
  paths.each_with_object([]) do |raw, result|
    value = raw.to_s.strip
    next if value.empty?

    path = source == :data ? File.expand_path(value, Dir.home) : File.expand_path(value)
    key = File::ALT_SEPARATOR ? path.downcase : path
    next if seen[key]

    seen[key] = true
    result << path
  end
end

def parse_options(argv)
  options = Options.new(retries: DEFAULT_RETRIES, new_files: true, quiet: false, color: nil)
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: gsna [options] [REPOSITORY ...]"
    opts.separator ""
    opts.separator "Synchronize git repositories. Without REPOSITORY arguments,"
    opts.separator "the list is read from `chezmoi data` (data.git.syncfolders)."
    opts.separator ""
    opts.on("--[no-]new-files", "Commit new/untracked files (default: yes)") do |value|
      options.new_files = value
    end
    opts.on("--retries N", Integer,
            "Retries after the first fetch/push attempt (default: #{DEFAULT_RETRIES}; delays 2, 4, 8 s)") do |value|
      raise OptionParser::InvalidArgument, "must be >= 0" if value.negative?

      options.retries = value
    end
    opts.on("-q", "--quiet", "Only print errors (and summary lines for failures)") do
      options.quiet = true
    end
    opts.on("--[no-]color", "Use ANSI colors (default: auto)") do |value|
      options.color = value
    end
    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit 0
    end
  end
  parser.parse!(argv)
  options
rescue OptionParser::ParseError => e
  warn "gsna: #{e.message}"
  warn parser
  exit 2
end

def main(argv)
  options = parse_options(argv)
  color = options.color.nil? ? ($stdout.tty? && ENV["NO_COLOR"].nil?) : options.color
  reporter = Reporter.new(quiet: options.quiet, color: color)

  source = argv.empty? ? :data : :cli
  raw_paths = source == :data ? folders_from_chezmoi : argv
  repositories = expand_repositories(raw_paths, source)

  if repositories.empty?
    reporter.warn("gsna: no repositories to synchronize")
    return 0
  end

  reporter.info("gsna: #{repositories.length} repository(ies) to synchronize")
  results = repositories.map { |path| sync_repository(path, source, options, reporter) }

  failed = results.select { |_path, status| status == :failed }
  skipped = results.select { |_path, status| status == :skipped }
  ok = results.select { |_path, status| status == :ok }

  unless options.quiet && failed.empty?
    reporter.section("Summary")
    results.each do |path, status|
      label = case status
              when :ok then "OK"
              when :skipped then "SKIPPED"
              else "FAILED"
              end
      line = "  #{label.ljust(7)} #{path}"
      status == :failed ? reporter.error(line) : reporter.info(line)
    end
  end

  if failed.any?
    reporter.error("gsna: #{failed.length} failed, #{skipped.length} skipped, #{ok.length} OK")
    1
  else
    reporter.ok("gsna: #{ok.length} OK, #{skipped.length} skipped") unless options.quiet
    0
  end
rescue GsnaError => e
  warn "gsna: #{e.message}"
  2
rescue Interrupt
  warn "\ngsna: interrupted"
  130
end

exit(main(ARGV.dup)) if $PROGRAM_NAME == __FILE__
