require 'yaml'
require 'dropbox_sdk'
require 'redcarpet'
require 'guid'
require 'pathname'
require 'fileutils'
require 'time'

class DropboximusPrime
  attr_accessor :settings, :markdown, :dropbox

  def initialize arg=nil
    @settings = init_settings(arg)
    @dropbox = init_dropbox
    @markdown = init_markdown
  end

  def get *items
    aggregate_paths(items).each_with_object({}) { |key, memo|
      memo[key] = get_item(cache_path(key))
    }
  end

  def get_one item
    get(item).values[0]
  end

  def refresh *items
    if items.length > 0
      local_paths = aggregate_paths(items)
    else
      local_paths = dropbox_list_files_recursively(@settings['dropbox']['path']).map! { |item|
        remote_path_to_relative_path item
      }
    end

    local_paths.each { |item|
      refresh_item(item)
    }
  end

  def prune!
    local_files = aggregate_paths(['**/*'])
    local_dirs = dirs_only(local_files)

    remote_files = dropbox_list_files_recursively(@settings['dropbox']['path']).each_with_object([]) { |x, memo|
      memo.push remote_path_to_relative_path(x)
    }
    remote_dirs = dropbox_list_dirs_recursively(@settings['dropbox']['path']).each_with_object([]) { |x, memo|
      memo.push remote_path_to_relative_path(x)
    }

    orphan_files = local_files.each_with_object([]) { |x, memo|
      memo.push x unless remote_files.include? x
    }
    orphan_dirs = local_dirs.each_with_object([]) { |x, memo|
      memo.push x unless remote_dirs.include? x
    }

    orphan_files.each { |x|
      FileUtils.rm(cache_path(x), force: true)
    }
    orphan_dirs.each { |x|
      FileUtils.rm(cache_path(x), force: true)
    }
  end

  #private

    def aggregate_paths items
      items.flatten.each_with_object([]) { |x, memo|
        Dir.glob(cache_path(x)).each { |y|
          memo.push relative_path(y) if File.file?(y) && !is_thumbnail?(y)
        }
      }
    end

    def get_item path
      return YAML.load_file(path) if is_yaml?(path)
      return @markdown.render(File.read(path)) if is_markdown?(path)
      return imagify(path) if is_image?(path)
    end

    DPImage = Struct.new(:url, :title, :alt, :thumbnail_s_url, :thumbnail_m_url, :thumbnail_l_url, :thumbnail_xl_url)
    def imagify relative_path
      url = public_path(relative_path)

      meta = get_image_meta(relative_path)
      alt = meta[0]
      title = meta[1]

      thumbnail_s_url = imagify_suffix url, '_s'
      thumbnail_m_url = imagify_suffix url, '_m'
      thumbnail_l_url = imagify_suffix url, '_l'
      thumbnail_xl_url = imagify_suffix url, '_xl'

      DPImage.new(url,title,alt,thumbnail_s_url,thumbnail_m_url,thumbnail_l_url,thumbnail_xl_url)
    end

    def imagify_suffix path, suffix
      File.join(File.dirname(path), insert_into_filename_before_extension(File.basename(path), suffix))
    end

    def get_image_meta relative_path
      begin
        cache_path = cache_path(relative_path)
        meta_file_path = File.join(File.dirname(cache_path), '_'+File.basename(cache_path,".*")+'.yml')
        meta = YAML.load_file(meta_file_path)
        [
          meta['alt'],
          meta['title']
        ]
      rescue
        [
          '',
          ''
        ]
      end
    end

    def cache_path relative_path
      File.join(@settings['cache']['path'], relative_path)
    end

    def relative_path cache_path
      new_path = cache_path.sub(@settings['cache']['path'], '')
      new_path[0] = '' if new_path[0] == '/'
      new_path
    end

    def remote_path relative_path
      File.join(@settings['dropbox']['path'], relative_path)
    end

    def remote_path_to_relative_path remote_path
      new_path = remote_path.sub(@settings['dropbox']['path'], '')
      new_path[0] = '' if new_path[0] == '/'
      new_path
    end

    def public_path relative_path
      File.join(@settings['cache']['http_prefix'], relative_path)
    end

    def insert_into_filename_before_extension(filename, insert)
      extension = File.extname(filename)
      filename.reverse.sub(extension.reverse, (insert + extension).reverse).reverse
    end

    def dirs_only(paths)
      paths.each_with_object([]) { |x, memo|
        memo.push File.dirname(x)
        memo.delete('.')
      }.uniq
    end

    def rev_path relative_path
      File.join(@settings['rev_cache']['path'], relative_path)
    end

    def set_rev relative_path, rev
      rev_path = rev_path(relative_path)
      rev_dir = File.dirname(rev_path)
      FileUtils::mkdir_p(rev_dir) unless File.directory?(rev_dir)
      File.open(rev_path, 'w') { |file| file.write(rev) }
    end

    def unset_rev relative_path
      rev_path = rev_path(relative_path)
      File.delete(rev_path)
    end

    def get_rev relative_path
      begin
        File.read(rev_path(relative_path))
      rescue
        return nil
      end
    end

    def is_image? filename
      ['.jpg', '.gif', '.png', '.bmp'].any? { |word| filename.end_with?(word) }
    end

    def is_markdown? filename
      ['.md','.markdown'].any? { |word| filename.end_with?(word) }
    end

    def is_yaml? filename
      ['.yml','.yaml'].any? { |word| filename.end_with?(word) }
    end

    def is_thumbnail? path
      thumbnail_suffixes.any? { |word| File.basename(path, ".*").end_with?(word) }
    end

    def init_markdown
      Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    end

    def init_dropbox
      DropboxClient.new(@settings['dropbox']['access_token'])
    end

    def dropbox_list_recursively(root_path, list=[])
      @dropbox.metadata(root_path)['contents'].each { |obj|
        dropbox_list_recursively(obj['path'], list) if obj['is_dir']
        list << obj
      }
      list
    end

    def dropbox_list_dirs_recursively(root_path, list=[])
      dropbox_list_recursively(root_path).each { |item| list << item['path'].downcase if item['is_dir'] == true }
      list
    end

    def dropbox_list_files_recursively(root_path, list=[])
      dropbox_list_recursively(root_path).each { |item| list << item['path'].downcase if item['is_dir'] == false }
      list
    end

    def refresh_item relative_path
      begin
        meta = @dropbox.metadata(remote_path(relative_path))
      rescue
        return false
      end

      remote_path = remote_path(relative_path)
      last_rev = get_rev(relative_path)
      current_rev = meta['rev']
      return relative_path if last_rev == current_rev

      dropbox_get(remote_path, current_rev)
      dropbox_get_thumbnails(remote_path) if is_image?(File.basename(remote_path))
      relative_path
    end

    def dropbox_get remote_path, rev=nil
      relative_path = remote_path_to_relative_path(remote_path)
      cache_path = cache_path(relative_path)
      cache_dir = File.dirname(cache_path)
      rev_path = rev_path(relative_path)
      tmp_path = make_tmp_path

      File.open(tmp_path, 'w') { |file| file.write(@dropbox.get_file(remote_path)) }
      FileUtils::mkdir_p(cache_dir) unless File.directory?(cache_dir)
      FileUtils.mv tmp_path, cache_path
      set_rev relative_path, rev if rev
    end

    def thumbnail_sizes
      ['s','m','l','xl']
    end

    def thumbnail_suffixes
      thumbnail_sizes.each_with_object([]) { |x, memo|
        memo.push '_'+x
      }
    end

    def dropbox_get_thumbnails(remote_path)
      relative_path = remote_path_to_relative_path(remote_path)
      cache_path = cache_path(relative_path)
      tmp_path = make_tmp_path

      return false unless is_image?(relative_path)

      thumbnail_sizes.each { |size|
        suffix = '_'+size
        File.open(tmp_path, 'w') { |file| file.write(@dropbox.thumbnail(remote_path, size)) }
        FileUtils.mv tmp_path, File.join(File.dirname(cache_path), insert_into_filename_before_extension(File.basename(cache_path), suffix))
      }
    end

    def make_tmp_path
      File.join(@settings['tmp_cache']['path'], Guid.new.to_s)
    end

    def init_settings arg
      return YAML.load_file('config/dropboximus_prime.yml') if !arg
      return YAML.load_file(arg) if arg.is_a? String
      return arg if arg.is_a? Hash
    end

end
