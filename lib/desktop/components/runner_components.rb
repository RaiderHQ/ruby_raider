require 'open3'
require 'yaml'
require_relative 'base_component'
require_relative '../../scaffolding/scaffolding'

class RunnerComponents < BaseComponent
  attr_accessor :contacts

  CONFIG_ITEM = Struct.new(:attribute, :value)
  CAP = Struct.new(:attribute, :value)

  def initialize
    super
    @folder_exist = File.directory?(@folder)
  end

  def header
    grid do
      stretchy false

      button('▶') do
        left 0
        on_clicked do
          output = Open3.popen3("#{@framework} #{@tests.selected_item}") do |_stdin, stdout, _stderr|
            stdout.read
          end
          system "#{@framework} #{@tests.selected_item}"
          @results.text = output
        end
      end
      button('■') do
        left 1
        on_clicked do
          pp 'The stop feature will be implemented in a later release'
        end
      end

      @tests = combobox do
        left 2
        files = Dir.glob(File.join(@folder, @extension))
        multiple_items = files.count.positive? ? files : ['There are no tests please create a new one']
        items multiple_items
        selected_item files.first
        @file = files.count.positive? ? File.open(files.first) : ''

        on_selected do |items|
          @results.text = ''
          path = items.selected_item
          @file = File.open(path)
          @text_box.text = @file.read
        end
      end

      button('Open Dashboard') do
        left 3
        halign :end
        on_clicked do
          system 'allure serve allure-reports'
        end
      end
    end
  end

  def tests_tab
    tab_item('Tests') do
      horizontal_box do
        @text_box = multiline_entry do
          test_code = @folder_exist ? @file.read : 'No tests have been created, please create your first test'
          text test_code

          on_changed do |e|
            File.write(@tests.selected_item, e.text)
            $stdout.flush # for Windows
          end
        end

        @results = multiline_entry do
          text ''
        end
      end
    end
  end

  def config_tab
    tab_item('Configuration') do
      @config_data = load_or_create_config
      @config_items = @config_data.map { |key, value| CONFIG_ITEM.new(key, value) }
      vertical_box do
        refined_table(
          model_array: @config_items,
          table_columns: {
            'Attribute' => :text,
            'Value' => { text: { editable: true } }
          },
          table_editable: true,
          per_page: 20
        )
      end
    end
  end

  def editor_tab
    tab_item('Editor') do
      horizontal_box do
        vertical_box do
          horizontal_box do
            button('Create Test') do
              on_clicked do
                Scaffolding.new([@test_name.text]).generate_spec
              end
            end
            @test_name = entry do
              text 'test_example'
            end
          end
          horizontal_box do
            button('Create Page') do
              on_clicked do
                Scaffolding.new([@page_name.text]).generate_class
              end
            end
            @page_name = entry do
              text 'page_example'
            end
          end
          horizontal_box do
            button('Create Helper') do
              on_clicked do
                Scaffolding.new([@helper_name.text]).generate_helper
              end
            end
            @helper_name = entry do
              text 'helper_example'
            end
          end
          vertical_separator do
            stretchy false
          end
        end
        vertical_box do
          @editable_files = combobox do
            @all_files = @folder_exist ? load_all_files : ['There are no files created']
            stretchy false
            visible true
            items @all_files
            selected_item @all_files.first

            on_selected do |items|
              if @folder_exist
                path = items.selected_item
                @edit_file = File.open(path)
                @edit_box.text = @edit_file.read
              end
            end
          end
          @edit_box = multiline_entry do
            text File.read(@all_files&.first) if @folder_exist

            on_changed do |e|
              if @folder_exist
                File.write(@editable_files.selected_item, e.text)
                $stdout.flush # for Windows
              end
            end
          end
        end
      end
    end
  end

  private

  def load_all_files
    test_files = Dir.glob(File.join(@folder, @extension))
    page_object_files = Dir.glob(File.join('page_objects/pages', '*.rb'))
    helper_files = Dir.glob(File.join('helpers', '*.rb'))
    test_files + page_object_files + helper_files
  end

  def load_or_create_config
    file_paths = {
      config: 'config/config.yml',
      caps: 'config/capabilities.yml',
      opts: 'config/options.yml'
    }

    loaded_files = file_paths.transform_values do |path|
      File.exist?(path) ? YAML.load_file(path) : {}
    end

    return { message: 'Create a config file to access your attributes' } if loaded_files.values.all?(&:empty?)

    loaded_files[:config].merge(loaded_files[:caps]).merge(loaded_files[:opts])
  end
end
