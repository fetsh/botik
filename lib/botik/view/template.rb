# frozen_string_literal: true

require "erubi"
require "digest"

module Botik
  module View
    # A compiled ERB template. Templates are compiled once into methods of
    # Botik::View::CompiledTemplates and recompiled when the file changes.
    class Template
      @cache = {}
      @mutex = Mutex.new

      class << self
        # Returns the (cached) template for +path+.
        def for(path)
          @mutex.synchronize { @cache[path] ||= new(path) }
        end

        def clear_cache
          @mutex.synchronize { @cache.clear }
        end
      end

      attr_reader :path, :format

      def initialize(path)
        @path = path
        @format = Formats.for(File.basename(path).split(".")[-2])
        @compiled = {}
        @mutex = Mutex.new
      end

      # Renders the template in +context+ and returns the output String.
      def render(context, locals = {})
        method_name = compiled_method(locals.keys.map(&:to_sym).sort)
        context.with_format(format) { context.__send__(method_name, locals) }
      end

      private

      def compiled_method(local_names)
        mtime = File.mtime(path).to_r
        key = [local_names, mtime]
        @mutex.synchronize do
          @compiled.delete_if { |(_, time), _| time != mtime }
          @compiled[key] ||= compile(local_names, mtime)
        end
      end

      def compile(local_names, mtime)
        method_name = "_botik_template_#{Digest::MD5.hexdigest([path, local_names, mtime].inspect)}"
        source = Erubi::Engine.new(
          File.read(path), escape: true, escapefunc: "_botik_escape", freeze_template_literals: false
        ).src
        assigns = local_names.map { |name| "#{name} = local_assigns[:#{name}];" }.join
        # Compiled into the template's own file and line so errors point at the template.
        CompiledTemplates.module_eval(
          "def #{method_name}(local_assigns); #{assigns} #{source}; end", __FILE__, __LINE__
        )
        method_name
      rescue SyntaxError => e
        raise Error, "syntax error in template #{path}: #{e.message}"
      end
    end

    # Holds the methods compiled from templates; included into View::Context.
    module CompiledTemplates; end

    # Finds templates in a list of view paths.
    class Resolver
      EXTENSIONS = Formats::EXTENSIONS.keys.freeze

      def initialize(paths)
        @paths = Array(paths).map(&:to_s)
      end

      # +name+ is either a template name relative to +prefix+ ("show") or a
      # path ("shared/footer"), looked up first under +namespace+ (the bot's view
      # directory, e.g. "shop_bot/shared/_footer") and then from the view root.
      # A leading slash ("/shared/footer") skips the bot's directory.
      # Partials get a leading underscore in the file name. +formats+ lists
      # preferred extensions.
      def find(name, prefix:, namespace: nil, partial: false, formats: [])
        extensions = (formats + EXTENSIONS).uniq
        candidates(name, prefix, namespace, partial).each do |logical|
          @paths.each do |root|
            extensions.each do |extension|
              file = File.join(root, "#{logical}.#{extension}.erb")
              return Template.for(file) if File.file?(file)
            end
          end
        end
        nil
      end

      def find!(name, prefix:, namespace: nil, partial: false, formats: [])
        find(name, prefix: prefix, namespace: namespace, partial: partial, formats: formats) or
          raise TemplateMissing, "missing template #{candidates(name, prefix, namespace, partial).join(' or ')} " \
                                 "in #{@paths.inspect}"
      end

      private

      def candidates(name, prefix, namespace, partial)
        name = name.to_s
        logicals = if name.start_with?("/")
                     [name.delete_prefix("/")]
                   elsif name.include?("/")
                     [namespace && "#{namespace}/#{name}", name].compact
                   else
                     ["#{prefix}/#{name}"]
                   end
        logicals.map do |logical|
          dir, base = File.split(logical)
          File.join(dir, partial ? "_#{base}" : base)
        end
      end
    end
  end
end
