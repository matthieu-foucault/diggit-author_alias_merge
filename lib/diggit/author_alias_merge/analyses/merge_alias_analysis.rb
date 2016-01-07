# encoding utf-8

require 'i18n'
require 'hash'
require 'set'

module Diggit
	module AuthorAliasMerge
		module Analyses
			class MergeAliasAnalysis < Diggit::Analysis
				require_addons 'db'

				@merge_groups = []
				@authors = Hash.new(0)

				def run
					Rugged::Walker.walk(repo) do |commit|
						author_name = normalize_name(commit.author[:name])
						author_mail = commit.author[:email]
						@authors << { name: author_name, email: author_mail }
					end

					@authors.each_with_index do |a1, i1|
						@authors.each do |a2, i2|
							next if i1 == i2
							next if tokens(a1).intersect(tokens(a2)).empty?
							puts "Same developer [yn]?"
							puts "#{a1[:name]}\t#{a1[:email]}"
							puts "#{a2[:name]}\t#{a2[:email]}"
							ans = gets
							puts "yes!" if ans == "y"
						end
					end
				end

				def tokens(author)
					tks = Set.new
					tks << author[:name].split(/[\s\-_\.,;!\?]/)
					tks << author[:email].slice(/^[^@]*/).split(/[\s\-_\.,;!\?]/)
					tks
				end

				def normalize_name(author_name)
					I18n.config.available_locales = :en
					I18n.transliterate(author_name.squish)
				end
			end
		end
	end
end
