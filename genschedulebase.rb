#! /usr/bin/ruby -E:UTF-8
# -*- mode:Ruby; tab-width:4; coding:UTF-8; -*-
# vi:set ft=ruby ts=4 fenc=UTF-8 :
#----------------------------------------------------------------
# eLTAX運転日スケジュール雛形作成
#----------------------------------------------------------------
require 'date'
require 'holiday_japan' # gem install holiday_japan

def genschedule(year)
	begin_day = Date.new(year, 4, 1)
	end_day = begin_day.next_month(12)

	puts("{")
	(begin_day ... end_day).each do |a_day|
		a_day_s = a_day.to_s
		if (hname = HolidayJapan.name(a_day))
			print("\t\"#{a_day_s}\": { \"op\":\"×\", \"holiday\":\"#{hname}\" }")
		elsif a_day.month == 1 && [1,2,3].include?(a_day.day)
			print("\t\"#{a_day_s}\": { \"op\":\"×\", \"holiday\":\"年始休\" }")
		elsif a_day.month == 12 && [29,30,31].include?(a_day.day)
			print("\t\"#{a_day_s}\": { \"op\":\"×\", \"holiday\":\"年末休\" }")
		elsif a_day.saturday? || a_day.sunday?
			print("\t\"#{a_day_s}\": { \"op\":\"×\" }")
		else
			print("\t\"#{a_day_s}\": { \"op\":\"○\" }")
		end
		if a_day.next_day >= end_day
			print("\n")
		else
			print(",\n")
			if a_day.next_day.month != a_day.month
				print("\n")
			end
		end
	end
	puts("}")
end

def main(args)
	if args.empty?
		puts("usage: #{$0} [year]")
	else
		genschedule(args[0].to_i)
	end

	return 0
end

exit main(ARGV)
