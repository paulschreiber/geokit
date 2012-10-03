module Geokit
  module Geocoders
    class FCCBroadbandGeocoder < Geocoder

      private
      # Template method which does the reverse-geocode lookup.
      def self.do_reverse_geocode(latlng)
        latlng=LatLng.normalize(latlng)
        res = self.call_geocoder_service("http://www.broadbandmap.gov/broadbandmap/census/all?format=json&latitude=#{Geokit::Inflector::url_escape(latlng.lat.to_s)}&longitude=#{Geokit::Inflector::url_escape(latlng.lng.to_s)}")
        return GeoLoc.new unless (res.is_a?(Net::HTTPSuccess) || res.is_a?(Net::HTTPOK))
        json = res.body
        logger.debug "FCC Broadband reverse-geocoding. LL: #{latlng}. Result: #{json}"
        self.json2GeoLoc(json)
      end

      # Template method which does the geocode lookup.
      #
      # ==== EXAMPLES
      # ll=GeoKit::LatLng.new(40, -85)
      # Geokit::Geocoders::FCCBroadbandGeocoder.geocode(ll) #
      # { "Results" : { "block" : [ { "FIPS" : "361130730003014",
      #             "envelope" : { "maxx" : -73.76316799999998,
      #                 "maxy" : 43.487499999999997,
      #                 "minx" : -73.78680799999997,
      #                 "miny" : 43.454506999999985
      #               },
      #             "geographyType" : "BLOCK2010"
      #           } ],
      #       "censusPlace" : [ { "envelope" : { "maxx" : -73.74748599999998,
      #                 "maxy" : 43.56577699999999,
      #                 "minx" : -73.82491099999999,
      #                 "miny" : 43.454506999999985
      #               },
      #             "fips" : "3678289",
      #             "geographyType" : "PLACE2010",
      #             "name" : "Warrensburg",
      #             "statefips" : "36"
      #           } ],
      #       "censusTract" : [ { "envelope" : { "maxx" : -73.72687899999998,
      #                 "maxy" : 43.63249599999999,
      #                 "minx" : -73.88537399999998,
      #                 "miny" : 43.39798799999999
      #               },
      #             "fips" : "36113073000",
      #             "geographyType" : "TRACT2010",
      #             "name" : "730",
      #             "stateFips" : "36"
      #           } ],
      #       "county" : [ { "envelope" : { "maxx" : -73.43657799999997,
      #                 "maxy" : 43.80368699999999,
      #                 "minx" : -74.21462499999997,
      #                 "miny" : 43.22212299999999
      #               },
      #             "fips" : "36113",
      #             "geographyType" : "COUNTY2010",
      #             "name" : "Warren",
      #             "stateFips" : "36"
      #           } ],
      #       "msa" : [ { "cbsa" : "24020",
      #             "envelope" : { "maxx" : -73.241390999999993,
      #                 "maxy" : 43.808481,
      #                 "minx" : -74.214624999999998,
      #                 "miny" : 42.941221999999996
      #               },
      #             "geocode" : "G3110",
      #             "geographyType" : "MSA2010",
      #             "name" : "Glens Falls, NY",
      #             "status" : "1",
      #             "type" : "M1"
      #           } ],
      #       "state" : [ { "envelope" : { "maxx" : -71.77749099999998,
      #                 "maxy" : 45.015864999999984,
      #                 "minx" : -79.76258999999997,
      #                 "miny" : 40.477398999999984
      #               },
      #             "fips" : "36",
      #             "geographyType" : "STATE2010",
      #             "name" : "New York",
      #             "stateCode" : "NY"
      #           } ],
      #       "congressionalDistrict" : [ { "districtId" : "20",
      #             "envelope" : { "maxx" : -73.24139100000002,
      #                 "maxy" : 44.34787699999998,
      #                 "minx" : -75.41966400000001,
      #                 "miny" : 41.62636500000002
      #               },
      #             "fips" : "3611120",
      #             "geographyType" : "CONGRESSIONAL_DISTRICT_2010",
      #             "name" : "Congressional District 20",
      #             "statefips" : "36"
      #           } ],
      #       "stateHouseDistrict" : [ { "envelope" : { "maxx" : -73.29359399999998,
      #                 "maxy" : 44.54684399999999,
      #                 "minx" : -74.86771199999998,
      #                 "miny" : 43.066752999999984
      #               },
      #             "fips" : "36113",
      #             "geographyType" : "STATE_HOUSE_DISTRICT_2010",
      #             "name" : "Assembly District 113",
      #             "stateFips" : "36"
      #           } ],
      #       "stateSenateDistrict" : [ { "envelope" : { "maxx" : -73.24139099999998,
      #                 "maxy" : 45.01083999999998,
      #                 "minx" : -74.86771199999998,
      #                 "miny" : 42.94122199999999
      #               },
      #             "fips" : "36045",
      #             "geographyType" : "STATE_SENATE_DISTRICT_2010",
      #             "name" : "State Senate District 45",
      #             "stateFips" : "36"
      #           } ]
      #     },
      #   "message" : [  ],
      #   "responseTime" : 76,
      #   "status" : "OK"
      # }

      def self.json2GeoLoc(json, address="")
        ret = nil
        results = MultiJson.load(json)

        if results.has_key?('Err') && results['Err']["msg"] == 'There are no results for this location'
          return GeoLoc.new
        end
        # this should probably be smarter.
        if results['status'] != 'OK'
          raise Geokit::Geocoders::GeocodeError
        end
        
        results = results["Results"]

        res = GeoLoc.new
        res.provider       = 'fcc_broadband'
        res.success        = true
        res.precision      = 'block'
        res.country_code   = 'US'

        res.block_fips    = results['block'][0]['FIPS'] if results['block']

        res.tract         = results['censusTract'][0]['name'] if results['censusTract']
        res.tract_fips    = results['censusTract'][0]['fips'] if results['censusTract']

        res.city          = results['censusPlace'][0]['name'] if results['censusPlace']
        res.city_fips     = results['censusPlace'][0]['fips'] if results['censusPlace']

        res.district      = results['county'][0]['name'] if results['county']
        res.district_fips = results['county'][0]['fips'] if results['county']

        res.msa           = results['msa'][0]['name'] if results['msa']
        res.cbsa          = results['msa'][0]['cbsa'] if results['msa']

        res.state         = results['state'][0]['stateCode'] if results['state']
        res.state_fips    = results['state'][0]['fips'] if results['state']

        res.congressional_district = results['congressionalDistrict'][0]['districtId']
        res.state_house_district   = results['stateHouseDistrict'][0]['name'].split(" ").last
        res.state_senate_district  = results['stateSenateDistrict'][0]['name'].split(" ").last

        res
      end
    end

  end
end
