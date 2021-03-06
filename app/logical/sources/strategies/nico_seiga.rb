# Image Direct URL
# * https://lohas.nicoseiga.jp/o/971eb8af9bbcde5c2e51d5ef3a2f62d6d9ff5552/1589933964/3583893
# * http://lohas.nicoseiga.jp/priv/3521156?e=1382558156&h=f2e089256abd1d453a455ec8f317a6c703e2cedf
# * http://lohas.nicoseiga.jp/priv/b80f86c0d8591b217e7513a9e175e94e00f3c7a1/1384936074/3583893
# * http://seiga.nicovideo.jp/image/source?id=3312222
#
# Image Page URL
# * https://seiga.nicovideo.jp/seiga/im3521156
#
# Manga Page URL
# * http://seiga.nicovideo.jp/watch/mg316708

module Sources
  module Strategies
    class NicoSeiga < Base
      URL = %r!\Ahttps?://(?:\w+\.)?nico(?:seiga|video)\.jp!
      DIRECT1 = %r!\Ahttps?://lohas\.nicoseiga\.jp/priv/[0-9a-f]+!
      DIRECT2 = %r!\Ahttps?://lohas\.nicoseiga\.jp/o/[0-9a-f]+/\d+/\d+!
      DIRECT3 = %r!\Ahttps?://seiga\.nicovideo\.jp/images/source/\d+!
      PAGE = %r!\Ahttps?://seiga\.nicovideo\.jp/seiga/im(\d+)!i
      PROFILE = %r!\Ahttps?://seiga\.nicovideo\.jp/user/illust/(\d+)!i
      MANGA_PAGE = %r!\Ahttps?://seiga\.nicovideo\.jp/watch/mg(\d+)!i

      def domains
        ["nicoseiga.jp", "nicovideo.jp"]
      end

      def site_name
        "Nico Seiga"
      end

      def image_urls
        if url =~ DIRECT1
          return [url]
        end

        if theme_id
          return api_client.image_ids.map do |image_id|
            "https://seiga.nicovideo.jp/image/source/#{image_id}"
          end
        end

        link = page.search("a#illust_link")

        if link.any?
          image_url = "http://seiga.nicovideo.jp" + link[0]["href"]
          page = agent.get(image_url) # need to follow this redirect while logged in or it won't work

          if page.is_a?(Mechanize::Image)
            return [page.uri.to_s]
          end

          images = page.search("div.illust_view_big").select {|x| x["data-src"] =~ /\/priv\//}

          if images.any?
            return ["http://lohas.nicoseiga.jp" + images[0]["data-src"]]
          end
        end

        raise "image url not found for (#{url}, #{referer_url})"
      end

      def page_url
        [url, referer_url].each do |x|
          if x =~ %r!\Ahttps?://lohas\.nicoseiga\.jp/o/[a-f0-9]+/\d+/(\d+)!
            return "http://seiga.nicovideo.jp/seiga/im#{$1}"
          end

          if x =~ %r{\Ahttps?://lohas\.nicoseiga\.jp/priv/(\d+)\?e=\d+&h=[a-f0-9]+}i
            return "http://seiga.nicovideo.jp/seiga/im#{$1}"
          end

          if x =~ %r{\Ahttps?://lohas\.nicoseiga\.jp/priv/[a-f0-9]+/\d+/(\d+)}i
            return "http://seiga.nicovideo.jp/seiga/im#{$1}"
          end

          if x =~ %r{\Ahttps?://lohas\.nicoseiga\.jp/priv/(\d+)}i
            return "http://seiga.nicovideo.jp/seiga/im#{$1}"
          end

          if x =~ %r{\Ahttps?://lohas\.nicoseiga\.jp//?thumb/(\d+)i?}i
            return "http://seiga.nicovideo.jp/seiga/im#{$1}"
          end

          if x =~ %r{/seiga/im\d+}
            return x
          end

          if x =~ %r{/watch/mg\d+}
            return x
          end

          if x =~ %r{/image/source\?id=(\d+)}
            return "http://seiga.nicovideo.jp/seiga/im#{$1}"
          end
        end

        return super
      end

      def canonical_url
        image_url
      end

      def profile_url
        if url =~ PROFILE
          return url
        end

        "http://seiga.nicovideo.jp/user/illust/#{api_client.user_id}"
      end

      def artist_name
        api_client.moniker
      end

      def artist_commentary_title
        api_client.title
      end

      def artist_commentary_desc
        api_client.desc
      end

      def normalize_for_source
        if illust_id.present?
          "https://seiga.nicovideo.jp/seiga/im#{illust_id}"
        elsif theme_id.present?
          "http://seiga.nicovideo.jp/watch/mg#{theme_id}"
        end
      end

      def tag_name
        "nicoseiga#{api_client.user_id}"
      end

      def tags
        string = page.at("meta[name=keywords]").try(:[], "content") || ""
        string.split(/,/).map do |name|
          [name, "https://seiga.nicovideo.jp/tag/#{CGI.escape(name)}"]
        end
      end
      memoize :tags

      def api_client
        if illust_id
          NicoSeigaApiClient.new(illust_id: illust_id)
        elsif theme_id
          NicoSeigaMangaApiClient.new(theme_id)
        end
      end
      memoize :api_client

      def illust_id
        if page_url =~ PAGE
          return $1.to_i
        end

        return nil
      end

      def theme_id
        if page_url =~ MANGA_PAGE
          return $1.to_i
        end

        return nil
      end

      def page
        doc = agent.get(page_url)

        if doc.search("a#link_btn_login").any?
          # Session cache is invalid, clear it and log in normally.
          Cache.delete("nico-seiga-session")
          doc = agent.get(page_url)
        end

        doc
      end
      memoize :page

      def agent
        NicoSeigaApiClient.agent
      end
      memoize :agent
    end
  end
end
