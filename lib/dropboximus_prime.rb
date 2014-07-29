require 'delegate'
require 'yaml'
require 'dropbox_sdk'
require 'redcarpet'
require 'guid'
require 'pathname'
require 'fileutils'

class DropboximusPrime
  attr_accessor :settings

  def initialize settings=false
    @settings = !settings ? YAML.load_file('config/drizzle_settings.yml') : settings
    @dropbox = DropboxClient.new(@settings['dropbox']['access_token'])
    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  end

  def get *items
    gotten = []
    items.each { |item| gotten << get_item(item) }
    gotten.length == 1 ? gotten.first : gotten
  end

  def get_item simple_path
    filepath = proper_path(simple_path)
    puts filepath

    return false unless File.exist?(filepath)

    item = File.read(filepath)

    return YAML.load(item) if is_yaml?(filepath)
    return @markdown.render(item) if is_markdown?(filepath)
    return image_info(simple_path) if is_image?(filepath)
    item
  end

  def refresh! *items
    items = dropbox_lsr_f(@settings['dropbox']['path']) unless items.length > 0
    items.each { |i| refresh_item!(dropbox_path_to_simple_path(i), @settings['cache']['timeout']) }
  end

  def refresh_item! simple_path, cache_timeout=nil
    filename = Pathname.new(simple_path).basename.to_s
    local_filepath = proper_path(simple_path)
    local_path = local_filepath.sub('/' + filename,'')
    dropbox_filepath = dropbox_path(simple_path)
    tmp_filepath = make_tmp_path

    return false unless item_stale?(local_filepath, cache_timeout)
    return false unless dropbox_file_exists?(dropbox_filepath)

    store(dropbox_filepath, local_filepath, local_path, tmp_filepath)

    if is_image? filename
      dropbox_thumbnail_sizes.each { |size| store_thumbnail(dropbox_filepath, local_filepath, local_path, tmp_filepath, size) }
    end
  end

  private

    def store(dropbox_filepath, local_filepath, local_path, tmp_filepath)
      File.open(tmp_filepath, 'w') { |file| file.write(@dropbox.get_file(dropbox_filepath)) }
      FileUtils::mkdir_p local_path unless File.directory? local_path
      FileUtils.mv tmp_filepath, local_filepath
    end

    def store_thumbnail(dropbox_filepath, local_filepath, local_path, tmp_filepath, size)
      extension = File.extname(local_filepath)
      File.open(tmp_filepath, 'w') { |file| file.write(@dropbox.thumbnail(dropbox_filepath, size)) }
      FileUtils::mkdir_p local_path unless File.directory? local_path
      FileUtils.mv tmp_filepath, local_filepath.sub(extension, '_' + size + extension)
    end

    def dropbox_path simple_path
      simple_path = strip_initial_path(simple_path)
      @settings['dropbox']['path'] + '/' + simple_path
    end

    def dropbox_path_to_simple_path dropbox_path
      dropbox_path.downcase.sub(@settings['dropbox']['path'].downcase + '/', '')
    end

    def dropbox_lsr(root_path, list=[])
      @dropbox.metadata(root_path)['contents'].each { |obj|
        dropbox_lsr(obj['path'], list) if obj['is_dir']
        list << obj
      }
      list
    end

    def dropbox_lsr_d root_path
      list = []
      dropbox_lsr(root_path).each { |item| list << item['path'].downcase if item['is_dir'] == true }
      list
    end

    def dropbox_lsr_f root_path
      list = []
      dropbox_lsr(root_path).each { |item| list << item['path'].downcase if item['is_dir'] == false }
      list
    end

    def dropbox_file_exists? path
      begin
        meta = @dropbox.metadata path
        !meta['is_deleted'] && !meta['is_dir']
      rescue
      end
    end

    def strip_initial_path simple_path
      simple_path = simple_path.sub('/','') if simple_path[0,1] == '/'
      simple_path = simple_path.sub('./','') if simple_path[0,2] == './'
      simple_path
    end

    def private_path simple_path
      simple_path = strip_initial_path(simple_path)
      @settings['cache']['path'] + '/' + simple_path
    end

    def public_path simple_path
      simple_path = strip_initial_path(simple_path)
      @settings['cache']['public_path'] + '/' + simple_path
    end

    def proper_path simple_path
      public_file?(simple_path) ? public_path(simple_path) : private_path(simple_path)
    end

    def make_tmp_path
      @settings['cache']['tmp_path'] + '/' + Guid.new.to_s
    end

    def dropbox_thumbnail_sizes
      ['s', 'm', 'l', 'xl']
    end

    def public_file? filepath
      Pathname.new(filepath).basename.to_s.index('_') != 0
    end

    def is_image? filename
      ['.jpg', '.gif', '.png', '.bmp'].any? { |word| filename.include?(word) }
    end

    def is_markdown? filename
      ['.md','.markdown'].any? { |word| filename.include?(word) }
    end

    def is_yaml? filename
      ['.yml','.yaml'].any? { |word| filename.include?(word) }
    end

    def item_stale? filepath, cache_timeout=nil
      return true unless File.exist? filepath
      cache_timeout ||= @settings['cache']['timeout']
      (Time.now - File.stat(filepath).mtime).to_i > cache_timeout
    end

    def image_info simple_path
      p_path = @settings['cache']['public_prefix'] + simple_path
      
      {
        'public_path' => p_path,
        'thumbnails' => {
          's' => insert_into_filename_before_extension(p_path, '_s'),
          'm' => insert_into_filename_before_extension(p_path, '_m'),
          'l' => insert_into_filename_before_extension(p_path, '_l'),
          'xl' => insert_into_filename_before_extension(p_path, '_xl')
        }
      }
    end

    def insert_into_filename_before_extension(filename, insert)
      extension = File.extname(filename)
      filename.reverse.sub(extension.reverse, (insert + extension).reverse).reverse
    end

end
