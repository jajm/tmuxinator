module Tmuxinator
  class Cli < Thor
    include Tmuxinator::Util

    attr_reader :command_list

    def initialize(*args)
      super
      @command_list = %w(commands copy debug delete doctor help implode list start version)
    end

    package_name "tmuxinator"

    desc "commands", "Lists commands available in tmuxinator"

    def commands
      puts command_list.join("\n")
    end

    desc "completions [arg1 arg2]", "Used for shell completion"

    def completions(arg)
      if %w(start open copy delete).include?(arg)
        configs = Tmuxinator::Config.configs
        puts configs
      end
    end

    desc "new [PROJECT]", "Create a new project file and open it in your editor"
    map "open" => :new
    map "o" => :new
    map "n" => :new

    def new(name)
      config = Tmuxinator::Config.project(name)

      unless Tmuxinator::Config.exists?(name)
        template = Tmuxinator::Config.default? ? Tmuxinator::Config.default : Tmuxinator::Config.sample
        erb  = Erubis::Eruby.new(File.read(template)).result(binding)
        File.open(config, "w") { |f| f.write(erb) }
      end

      Kernel.system("$EDITOR #{config}") || doctor
    end

    desc "start [PROJECT]", "Start a tmux session using a project's tmuxinator config"
    map "s" => :start

    def start(name)
      project = Tmuxinator::Config.validate(name)

      if project.deprecations.any?
        project.deprecations.each { |deprecation| say deprecation, :red }
        puts
        print "Press ENTER to continue."
        STDIN.getc
      end

      Kernel.exec(project.render)
    end

    desc "debug [PROJECT]", "Output the shell commands that are generated by tmuxinator"

    def debug(name)
      project = Tmuxinator::Config.validate(name)
      puts project.render
    end

    desc "copy [EXISTING] [NEW]", "Copy an existing project to a new project and open it in your editor"
    map "c" => :copy
    map "cp" => :copy

    def copy(existing, new)
      existing_config_path = Tmuxinator::Config.project(existing)
      new_config_path = Tmuxinator::Config.project(new)

      exit!("Project #{existing} doesn't exist!") unless Tmuxinator::Config.exists?(existing)

      if Tmuxinator::Config.exists?(new)
        if yes?("#{new} already exists, would you like to overwrite it?", :red)
          FileUtils.rm(new_config_path)
          say "Overwriting #{new}"
        end
      end

      FileUtils.copy_file(existing_config_path, new_config_path)
      Kernel.system("$EDITOR #{new_config_path}")
    end

    desc "delete [PROJECT]", "Deletes given project"
    map "d" => :delete
    map "rm" => :delete

    def delete(project)
      if Tmuxinator::Config.exists?(project)
        config =  "#{Tmuxinator::Config.root}/#{project}.yml"

        if yes?("Are you sure you want to delete #{project}?(y/n)", :red)
          FileUtils.rm(config)
          say "Deleted #{project}"
        end
      else
        exit! "That file doesn't exist."
      end
    end

    desc "implode", "Deletes all tmuxinator projects"
    map "i" => :implode

    def implode
      if yes?("Are you sure you want to delete all tmuxinator configs?", :red)
        FileUtils.remove_dir(Tmuxinator::Config.root)
        say "Deleted all tmuxinator projects."
      end
    end

    desc "list", "Lists all tmuxinator projects"
    map "l" => :list
    map "ls" => :list

    def list
      say "tmuxinator projects:"

      print_in_columns Tmuxinator::Config.configs
    end

    desc "version", "Display installed tmuxinator version"
    map "-v" => :version

    def version
      say "tmuxinator #{Tmuxinator::VERSION}"
    end

    desc "doctor", "Look for problems in your configuration"

    def doctor
      say "Checking if tmux is installed ==> "
      yes_no Tmuxinator::Config.installed?

      say "Checking if $EDITOR is set ==> "
      yes_no Tmuxinator::Config.editor?

      say "Checking if $SHELL is set ==> "
      yes_no  Tmuxinator::Config.shell?
    end
  end
end
