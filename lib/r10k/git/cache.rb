require 'r10k/logging'

require 'r10k/git'
require 'r10k/git/repository'

require 'r10k/settings'
require 'r10k/registry'

class R10K::Git::Cache < R10K::Git::Repository
  # Mirror a git repository for use shared git object repositories
  #
  # @see man git-clone(1)

  include R10K::Settings::Mixin

  def_setting_attr :cache_root, File.expand_path(ENV['HOME'] ? '~/.r10k/git': '/root/.r10k/git')

  def self.registry
    @registry ||= R10K::Registry.new(self)
  end

  def self.generate(remote)
    registry.generate(remote)
  end

  include R10K::Logging

  # @!attribute [r] remote
  #   @return [String] The git repository remote
  attr_reader :remote

  # @!attribute [r] path
  #   @deprecated
  #   @return [String] The path to the git cache repository
  def path
    logger.warn "#{self.class}#path is deprecated; use #git_dir"
  end

  # @param [String] remote
  # @param [String] cache_root
  def initialize(remote)
    @remote = remote

    @path = File.join(settings[:cache_root], sanitized_dirname)
    git_dir = @path
  end

  def sync
    if not @synced
      sync!
      @synced = true
    end
  end

  def sync!
    if cached?
      git "fetch --prune", :git_dir => git_dir
    else
      logger.debug "Creating new git cache for #{@remote.inspect}"

      # TODO extract this to an initialization step
      unless File.exist? settings[:cache_root]
        FileUtils.mkdir_p settings[:cache_root]
      end

      git "clone --mirror #{@remote} #{git_dir}"
    end
  rescue R10K::ExecutionFailure => e
    if (msg = e.stderr[/^fatal: .*$/])
      raise R10K::Git::GitError, "Couldn't update git cache for #{@remote}: #{msg.inspect}"
    else
      raise e
    end
  end

  # @return [Array<String>] A list the branches for the git repository
  def branches
    output = git 'for-each-ref refs/heads --format "%(refname)"', :git_dir => git_dir
    output.scan(%r[refs/heads/(.*)$]).flatten
  end

  # @return [true, false] If the repository has been locally cached
  def cached?
    File.exist? git_dir
  end

  private

  # Reformat the remote name into something that can be used as a directory
  def sanitized_dirname
    @remote.gsub(/[^@\w\.-]/, '-')
  end
end
