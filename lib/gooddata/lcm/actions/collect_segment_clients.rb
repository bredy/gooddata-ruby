# encoding: UTF-8
#
# Copyright (c) 2010-2016 GoodData Corporation. All rights reserved.
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

require_relative 'base_action'

module GoodData
  module LCM2
    class CollectSegmentClients < BaseAction
      DESCRIPTION = 'Collect Clients'

      PARAMS = define_params(self) do
        description 'Client Used for Connecting to GD'
        param :gdc_gd_client, instance_of(Type::GdClientType), required: true

        description 'Organization Name'
        param :organization, instance_of(Type::StringType), required: true

        description 'ADS Client'
        param :ads_client, instance_of(Type::AdsClientType), required: true
      end

      RESULT_HEADER = [
        :from_name,
        :from_pid,
        :to_name,
        :to_pid
      ]

      DEFAULT_QUERY_SELECT = 'SELECT segment_id, master_project_id, version from lcm_release WHERE segment_id=\'#{segment_id}\';'

      class << self
        def call(params)
          # Check if all required parameters were passed
          BaseAction.check_params(PARAMS, params)

          client = params.gdc_gd_client

          domain_name = params.organization || params.domain
          domain = client.domain(domain_name) || fail("Invalid domain name specified - #{domain_name}")
          domain_segments = domain.segments

          segments = params.segments.map do |seg|
            domain_segments.find do |s|
              s.segment_id == seg.segment_id
            end
          end

          results = []
          synchronize_clients = segments.map do |segment|
            res = params.ads_client.execute_select(DEFAULT_QUERY_SELECT.gsub('#{segment_id}', segment.segment_id))

            # TODO: Check res.first.nil? || res.first[:master_project_id].nil?
            master = client.projects(res.first[:master_project_id])
            master_pid = master.pid
            master_name = master.title

            sync_info = {
              from: master_pid,
              to: segment.clients.map do |client|
                client_project = client.project
                to_pid = client_project.pid
                results << {
                  from_name: master_name,
                  from_pid: master_pid,
                  to_name: client_project.title,
                  to_pid: to_pid,
                }
                to_pid
              end
            }

            sync_info
          end

          results.flatten!

          # Return results
          {
            results: results,
            params: {
              synchronize: synchronize_clients
            }
          }
        end
      end
    end
  end
end
