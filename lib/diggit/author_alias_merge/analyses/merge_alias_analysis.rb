# encoding utf-8

require 'i18n'
require 'set'

module Diggit
	module AuthorAliasMerge
		module Analyses
			class MergeAliasAnalysis < Diggit::Analysis
				require_addons 'db', 'src_opt'

				def run
					@merge_groups = []
					@authors = Set.new
					Rugged::Walker.walk(repo, show: src_opt[@source]["cloc-commit-id"], hide: src_opt[@source]["R_first"]) do |commit|
						author_name = normalize_name(commit.author[:name])
						author_mail = commit.author[:email]
						@authors << { name: author_name, email: author_mail }
					end
					num_authors = @authors.length
					num_pairs_tested = 0
					num_pairs_validated = 0
					@authors.to_a.combination(2).each do |pair|
						a = pair[0]
						b = pair[1]
						next if (tokens(a) & tokens(b)).empty?
						if a[:email] == b[:email] || a[:name] == b[:name]
							add_to_merge_groups(pair.to_set)
							next
						end
						next if only_name_or_surname_in_common?(a, b)

						puts "Same developer [y/N]?"
						puts "#{a[:name]}\t#{a[:email]}"
						puts "#{b[:name]}\t#{b[:email]}"
						num_pairs_tested += 1
						next if $stdin.gets.strip != 'y'
						num_pairs_validated += 1

						puts 'Adding to merge groups'
						add_to_merge_groups(pair.to_set)
						puts @merge_groups.inspect
					end
					db.client["merge_alias_stats"].insert_one({ source: @source.url, num_authors: num_authors,
						num_pairs_tested: num_pairs_tested,
						num_pairs_validated: num_pairs_validated })
					save_merge_groups
				end

				def clean
					db.client["merge_alias_stats"].find({ source: @source.url }).delete_many
					db.client["merge_groups"].find({ source: @source.url }).delete_many
				end

				def save_merge_groups
					@merge_groups.each { |mg| db.client["merge_groups"].insert_one({ source: @source.url, merge_group: mg.to_a }) }
				end

				def add_to_merge_groups(author_pair)
					@merge_groups.each_with_index do |mg, idx|
						unless (author_pair & mg).empty?
							@merge_groups[idx] += author_pair
							return false
						end
					end
					@merge_groups << author_pair
					true
				end

				# Most common case of false positive : a first name or surname in common
				def only_name_or_surname_in_common?(a, b)
					name_a = a[:name].strip.split(/\s/)
					name_b = b[:name].strip.split(/\s/)
					return false if name_a.length != 2 || name_b.length != 2 || a[:email] == b[:email]
					(name_a.to_set & name_b.to_set).length == 1
				end

				TOKENS_IGNORE = %w(github git dev contact)
				def tokens(author)
					tks = Set.new
					tks += author[:name].split(/[\s\-_\.,;!\?]/)
					email_tokens = author[:email].slice(/^[^@]*/).split(/[\s\-_\.,;!\?\+]/)
					if email_tokens.length == 1 && email_tokens[0] == 'github'
						# for those that have a personal website, the email may be github@mysite.com
						email_tokens = author[:email].match(/@([^\.]*)/)[1].split(/[\s\-_\.,;!\?\+]/)
					end
					tks += email_tokens
					tks.select { |e| e.length >= 3 && !TOKENS_IGNORE.include?(e) }
				end

				def normalize_name(author_name)
					I18n.config.available_locales = :en
					I18n.transliterate(author_name.strip).downcase
				end
			end
		end
	end
end
