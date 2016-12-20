#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'open-uri'
require 'csv'
require 'yajl/json_gem'

require 'pry'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

term_data = <<'EOT'
id,name,start_date,end_date
1,1st Assembly,1998-06-25,2003-04-28
2,2nd Assembly,2003-11-26,2007-01-30
3,3rd Assembly,2007-03-09,2011-03-24
4,4th Assembly,2011-05-06,
EOT

def json_load(file)
  JSON.parse(open(file).read, symbolize_names: true)
end

@terms = CSV.parse(term_data, headers: true, header_converters: :symbol)

file = 'http://cdn.rawgit.com/mysociety/parlparse/98435d1e57607dd091ff8f52c72f9ccb86b53c4c/members/people.json'
@json = json_load(file)

# Eileen Bell as Speaker
@json[:memberships].find { |m| m[:id] == 'uk.org.publicwhip/member/90241' }[:legislative_period_id] = '2'

#----------



def display_name(name)
  if name.key? :lordname
    display = "#{name[:honorific_prefix]} #{name[:lordname]}"
    display += " of #{name[:lordofname]}" unless name[:lordofname].to_s.empty?
    return display
  end
  name[:given_name] + " " + name[:family_name]
end

def name_at(p, date)
  date = DateTime.now.to_date.to_s if date.to_s.empty?
  at_date = p[:other_names].find_all { |n| 
    n[:note].to_s == 'Main' && (n[:end_date] || '9999-99-99') >= date && (n[:start_date] || '0000-00-00') <= date 
  }
  raise "Too many names at #{date}: #{at_date}" if at_date.count > 1
  return display_name(at_date.first)
end

def term_id(m)
  s_date = m[:start_date]
  e_date = m[:end_date] || '2100-01-01'
  matched = @terms.find_all { |t| (s_date >= t[:start_date]) and (e_date <= (t[:end_date] || '2100-01-01')) }
  return matched.first[:id] if matched.count == 1
  binding.pry
end


posts = @json[:posts].find_all { |p| p[:organization_id] == 'northern-ireland-assembly' }
post_ids = posts.map { |p| p[:id] }.to_set

@json[:memberships].find_all { |m| post_ids.include?  m[:post_id] }.each do |m|
  person = @json[:persons].find { |p| p[:id] == m[:person_id] }
  party  = @json[:organizations].find { |o| o[:id] == m[:on_behalf_of_id] }

  data = {
    id: person[:id].split('/').last,
    name: name_at(person, m[:start_date]),
    historichansard: person[:identifiers].to_a.find(->{{}}) { |id| id[:scheme] == 'historichansard_person_id' }[:identifier],
    party: party[:name],
    party_id: party[:id],
    start_date: m[:start_date],
    start_reason: m[:start_reason],
    end_date: m[:end_date],
    end_reason: m[:end_reason],
    term: m[:legislative_period_id] || term_id(m),
  }
  # puts data
  ScraperWiki.save_sqlite([:id, :term], data)
end



