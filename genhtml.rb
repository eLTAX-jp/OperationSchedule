#! /usr/bin/ruby -E:UTF-8
# -*- mode:Ruby; tab-width:4; coding:UTF-8; -*-
# vi:set ft=ruby ts=4 fenc=UTF-8 :
#----------------------------------------------------------------
# eLTAX運転日カレンダー生成
#----------------------------------------------------------------
require 'date'
require 'json'
require 'nokogiri'

class Date
	# 週の開始日かどうか
	def left_day?
		return monday?
	end

	# 週の終了日かどうか
	def right_day?
		return next_day.left_day?
	end

	# 奇数月かどうか
	def oddmonth?
		return month % 2 == 1
	end

	# 明日は次の月かどうか
	def tomorrow_is_nextmonth?
		return month != next_day.month
	end

	# 来週は次の月かどうか
	def nextweek_is_nextmonth?
		return month != next_day(7).month
	end

	# 先週は前の月かどうか
	def lastweek_is_lastmonth?
		return month != prev_day(7).month
	end
end

# JSONを読み込む
def read_json(filename)
	return JSON.parse(File.read(filename, external_encoding:"UTF-8"))
end

# 電子申告システム運転時間
# in:
#   "yyyy-mm-dd"
# out:
#   "◎" (0:00～24:00)
#   "○" (8:30～24:00)
#   "×" (休止中)
#   nil  (入力値不正または範囲外)
def eLTAX_op(a_day)
	a_day = a_day.to_s[0, 10]

	if $op_table[a_day]
		return $op_table[a_day]["op"]
	else
		return nil
	end
end

# 祝日&振替休日
# in:
#   "yyyy-mm-dd"
# out:
#   "○○の日" (祝日)
#   nil        (祝日でない または入力値不正または範囲外)
def holiday(a_day)
	a_day = a_day.to_s[0, 10]

	if $op_table[a_day]
		return $op_table[a_day]["holiday"]
	else
		return nil
	end
end

# 和暦年の文字列を得る "2024"→"R6"
def wareki(year)
	r = Date.new(year, 4, 1).jisx0301[0, 3]
	r[1, 1] = ""  if r[1, 1] == "0"
	return r
end

# 表のヘッダを挿入する
def insert_header(body)
	body.div(class:"table-header") do |body|
		body.div(class:"table-header1") do |body|
			body.span("", class:"table-header-l")
			body.span("#{$year}(#{wareki($year)})年度", class:"table-header1-r")
		end
		body.div(class:"table-header2") do |body|
			body.span("", class:"table-header-l")
			body.span("月", class:"table-header2-r")
			body.span("火", class:"table-header2-r")
			body.span("水", class:"table-header2-r")
			body.span("木", class:"table-header2-r")
			body.span("金", class:"table-header2-r")
			body.span("土", class:"table-header2-r saturday")
			body.span("日", class:"table-header2-r sunday no-right-border")
		end
	end
end

# 表の左端の月の列を挿入する
def insert_month(body, a_day, table_range)
	if a_day.lastweek_is_lastmonth?
		txt = "#{a_day.month}月"
	else
		txt = ""
	end

	# 表の最後の週かどうか
	endoftable = a_day.next_day(7) >= table_range.end

	cls = endoftable ? " border-bottom-endtable" : a_day.nextweek_is_nextmonth? ? " border-bottom-black" : ""
	cls += a_day.oddmonth? ? " oddmonth" : ""
	body.span(txt, class:"month#{cls}")
end

# 1日分のボックスを挿入する
def insert_day_box(body, a_day, table_range)
	# 休日
	holiday = holiday(a_day)

	# 作成範囲外(前年度/翌年度)かどうか
	out_of_scope = (a_day.prev_month(3).year != $year)

	# 表の最後の週かどうか
	endoftable = a_day.next_day(7) >= table_range.end

	cls = a_day.oddmonth? ? " oddmonth" : ""
	cls += a_day.right_day? ? " no-right-border" : a_day.tomorrow_is_nextmonth? ? " border-right-black" : ""
	cls += endoftable ? " border-bottom-endtable" : a_day.nextweek_is_nextmonth? ? " border-bottom-black" : ""
	cls += out_of_scope ? " box-outyear" : ""
	body.span(class:"day-box#{cls}") do |body|
		# 日
		cls = a_day.saturday? ? " saturday" : (a_day.sunday? || holiday) ? " sunday" : ""
		cls += out_of_scope ? " outyear" : ""
		body.span("#{a_day.day}", class:"day-label#{cls}")

		# 運用状況
		if !out_of_scope
			body.span("", class:"op-box") do |body|
				case eLTAX_op(a_day)
				when "◎"
					body.span("", class:"full-work-box")
				when "○"
					body.span("", class:"work-box")
				when "×"
					body.span(holiday ? "" : "休止中", class:"rest-box")
				end
			end
		end

		# 祝日
		if holiday
			cls = (holiday.length > 5) ? " smallfont" : ""
			cls += out_of_scope ? " outyear" : ""
			body.span("#{holiday}", class:"holiday sunday#{cls}")
		end
	end
end

# 指定範囲のテーブルを挿入する
def insert_table(body, range)
	body.div(class:"a-column") do |body|
		# 表ヘッダーの生成
		insert_header(body)

		# カレンダー範囲日の算出
		cal_begin_day = range.begin
		while(!cal_begin_day.left_day?) do
			cal_begin_day = cal_begin_day.prev_day
		end

		cal_end_day = range.end
		while(!cal_end_day.left_day?) do
			cal_end_day = cal_end_day.next_day
		end

		# カレンダー本体の生成
		cal_range = cal_begin_day ... cal_end_day
		cal_range.each do |a_day|
			# 左端の月
			if a_day.left_day?
				insert_month(body, a_day, cal_range)
			end

			# 日
			insert_day_box(body, a_day, cal_range)

			# 右端の線
			if a_day.right_day?
				body.span("", class:"weekend-sepalator")
				body.br
			end
		end
	end
end

def genhtml
	$op_table = read_json("docs/schedule.json")

	doc = Nokogiri::HTML::Document.parse(<<~EOF)
		<!doctype html>
		<html lang="ja-JP">
			<head>
				<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
				<title>#{$year}(#{wareki($year)})年度 eLTAX運転日カレンダー</title>
				<link href="style.css" rel="stylesheet" type="text/css">
			</head>
			<body>
			</body>
		</html>
	EOF

	body = doc.at_css("body")
	Nokogiri::HTML::Builder.with(body) do |body|
		# 表題
		body.h1("#{$year}(#{wareki($year)})年度 eLTAX運転日カレンダー")

		# 凡例
		body.div(class:"legend") do |body|
			body.text("電子申告システム運転時間 : ")
			body.span("■ 0:00～24:00", class:"full-work")
			body << "&ensp;";
			body.span("■ 8:30～24:00", class:"work")
			body << "&ensp;";
			body.span("■ 休止中", class:"rest")
		end

		body.div(class:"col2-table") do |body|
			# 1段目 (4～9月)
			begin_day = Date.new($year, 4, 1)
			end_day = begin_day.next_month(6) # 10/1
			insert_table(body, begin_day ... end_day)

			# 2段目 (10～3月)
			begin_day = Date.new($year, 10, 1)
			end_day = begin_day.next_month(6) # 4/1
			insert_table(body, begin_day ... end_day)
		end
	end

	ofilename = sprintf("%04d0401-%04d0331.html", $year, $year + 1)
	File.write("docs/#{ofilename}", doc.to_html, external_encoding:"UTF-8")

	return 0
end

def main(args)
	if args.empty?
		$year = Date.today.year
		genhtml
	else
		args.each do |year|
			$year = year.to_i
			genhtml
		end
	end

	return 0
end

exit main(ARGV)
