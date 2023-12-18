(use spork/misc)

(defn- _format-date [{:month m :year y :month-day d}]
  (string/format "%.4i-%.2i-%.2i" y (inc m) (inc d)))

(def midnite
  "Start of the day struct."
  {:hours 0 :minutes 0 :seconds 0})

(def year-start
  "Start of the year struct."
  {:month 0 :year-day 0 :month 0 :month-day 0})

(def month-start
  "Start of the month struct."
  {:month-day 0})

(def week-days
  "Register for week days names and abbrevs"
  {:short ["Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"]
   :long ["Sunday" "Monday" "Tuesday" "Wednesday"
          "Thursday" "Friday" "Saturday"]})
(def months
  "Register of months names and abbrevs."
  {:short
   ["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]
   :long
   ["January" "February" "March" "April" "May" "June" "July" "August"
    "September" "October" "November" "December"]})

# TODO make fns non anymous, part of the api.
(def Date
  "Prototype for the `Date` objects"
  @{:format _format-date
    :epoch os/mktime
    :str-week-day
    (fn [{:week-day wd} &opt frm]
      (default frm :short)
      (get-in week-days [frm wd]))
    :str-month
    (fn [{:month m} &opt frm]
      (default frm :short)
      (get-in months [frm m]))
    :local (fn [dt] (merge-into dt (os/date (os/mktime dt) true)))})

# TODO make fns non anymous, part of the api.
(def DateTime
  "Prototype for the `DateTime` objects"
  (make
    Date
    :format
    (fn [{:month m :year y :month-day d
          :minutes u :hours h :seconds s}]
      (string/format "%s %i:%.2i:%.2i"
                     (_format-date {:month m :year y :month-day d})
                     h u s))
    :http-format
    (fn [self]
      (def {:month m :year y :month-day d :week-day wd
            :minutes u :hours h :seconds s} (os/date (:epoch self)))
      (string/format "%s, %.2i %s %.4i %i:%.2i:%.2i GMT"
                     (get-in week-days [:short wd]) (inc d)
                     (get-in months [:short m]) y h u s))))

(defn- table-date [] (merge (os/date)))

(defn now
  "Returns current `DateTime`."
  []
  (table/setproto (table-date) DateTime))

(defn today
  "Returns today's `Date`"
  []
  (table/setproto (merge (table-date) midnite) Date))

(defn- nc [c &opt dc] (fn [n] {c ((if dc dec identity) (scan-number n))}))
(defn- mc [& cs] (merge ;cs))
(def- date-time-grammar
  (peg/compile
    ~{:date-sep (set "-/")
      :time-sep ":"
      :date-time-sep (set " T")
      :year (/ '(repeat 4 :d) ,(nc :year))
      :month (/ '(+ (* "0" :d)
                    (* "1" (range "02"))) ,(nc :month true))
      :month-day (/ '(+ (* (range "02") :d)
                        (* "3" (set "01"))) ,(nc :month-day true))
      :hours (/ '(+ (* (set "01") :d)
                    (* "2" (range "03"))) ,(nc :hours))
      :sixty (* (range "05") :d)
      :minutes (/ ':sixty ,(nc :minutes))
      :seconds (/ ':sixty ,(nc :seconds))
      :main (/ (* :year
                  (? (* :date-sep :month
                        (? (* :date-sep :month-day
                              (? (* :date-time-sep
                                    :hours
                                    (? (* :time-sep :minutes
                                          (? (* :time-sep :seconds)))))))))))
               ,mc)}))

(defn- from-string [x]
  (merge
    year-start
    month-start
    midnite ;(peg/match date-time-grammar x)))

(defn- normalize [x]
  (case (type x)
    :table x
    :struct (merge x)
    :number (merge (os/date x))
    :string (from-string x)))

(defn make-date
  "Convenience factory for creating `Date` objects."
  [date] # name?
  (def d (normalize date))
  (table/setproto (merge (os/date (os/mktime (merge d midnite)))) Date))

(defn make-date-time
  "Convenience factory for creating `DateTime` objects."
  [date-time &opt local]
  (table/setproto (merge (os/date (os/mktime (normalize date-time) local))) DateTime))

# TODO make fns non anymous, part of the api.
(def Interval
  "Prototype for the `Interval` objects"
  @{:format
    (fn [{:duration dur} &opt no-secs]
      (def h (math/floor (/ dur 3600)))
      (def m (math/floor (/ (- dur (* h 3600)) 60)))
      (def s (mod dur 60))
      (if no-secs
        (string/format "%i:%.2i" h m)
        (string/format "%i:%.2i:%.2i" h m s)))
    :compare
    (fn [{:duration md} {:duration od}]
      (compare md od))
    :add
    (fn [{:duration md} {:duration od}]
      @{:duration (+ md od)})
    :sub
    (fn [{:duration md} {:duration od}]
      @{:duration (- md od)})
    :in-years
    (fn [{:duration md}]
      (math/floor (/ md (* 60 60 24 365))))
    :in-days
    (fn [{:duration md}]
      (math/floor (/ md (* 60 60 24))))
    :in-hours
    (fn [{:duration md}]
      (math/floor (/ md (* 60 60))))
    :in-minutes
    (fn [{:duration md}]
      (math/floor (/ md (* 60))))})

(defn minutes
  "Returns amount of seconds in minutes `m`"
  [m]
  (* 60 (or m 0)))

(defn hours
  "Returns amount of seconds in hours `h`"
  [h]
  (* 60 (minutes h)))

(defn days
  "Returns amount of seconds in days `d`"
  [d]
  (* 24 (hours d)))

(defn weeks
  "Returns amount of seconds in weeks `w`"
  [w]
  (* 7 (days w)))

(defn years
  "Returns amount of seconds in years `y`"
  [y]
  (* 365 (days y)))

(defn- secs
  [&opt m]
  (default m 1)
  (fn [t] (* (scan-number t) m)))

(def- duration-grammar
  (comptime
    (peg/compile
      ~{:num (range "09")
        :reqwsoe (+ (some :s+) -1)
        :optws (any :s+)
        :secs (/ '(some :num) ,(secs))
        :mins (/ '(some :num) ,(secs 60))
        :hrs (/ '(some :num) ,(secs 3600))
        :tsecs (* :secs :optws (* "s" (any "ec") (any "ond") (any "s")))
        :tmins (* :mins :optws (* "m" (any "in") (any "ute") (any "s")) :optws)
        :thrs (* :hrs :optws (* "h" (+ (any "rs") (any "our"))
                                (any "s")) :optws)
        :text (* (any :thrs) (any :tmins) (any :tsecs))
        :colon (* :hrs ":" :mins (any (if ":" (* ":" :secs))))
        :main (+ (some :text) (some :colon))})))

(defn- from-string-dur [s]
  (-?> (peg/match duration-grammar s) sum))

(defn- from-dictionary
  [interval]
  (cond
    (interval :duration)
    (interval :duration)
    (interval :start)
    (- (interval :end) (interval :start))
    (let [{:years y
           :days d
           :hours h
           :minutes m
           :seconds s} interval]
      (+ (or s 0) (minutes m)
         (hours h)
         (days d)
         (years y)))))

(defn make-interval
  "Convenience factory for creating `Interval` objects."
  [interval]
  (make
    Interval
    :duration
    (case (type interval)
      :table (from-dictionary interval)
      :struct (from-dictionary interval)
      :number interval
      :string (from-string-dur interval))))

# TODO make fns non anymous, part of the api.
(def Calendar
  "Prototype for the `Calendar` objects"
  (make
    DateTime
    :sooner
    (fn [self interval]
      (make-date-time
        (- (:epoch self)
           ((make-interval interval) :duration))))
    :later
    (fn [self interval]
      (make-date-time
        (+ (:epoch self)
           ((make-interval interval) :duration))))
    :compare
    (fn [self other]
      (compare (:epoch self)
               (:epoch other)))
    :before?
    (fn [self date-time]
      (compare< self date-time))
    :after?
    (fn [self date-time]
      (compare> self date-time))))

(defn make-calendar
  "Convenience factory for creating `Calendar` objects."
  [date-time]
  (table/setproto
    (make-date-time date-time)
    Calendar))

# TODO make fns non anymous, part of the api.
(def Period
  "Prototype for the `Period` objects"
  (make
    Calendar
    :later
    (fn [self interval]
      (make-date-time
        (+ (:epoch self)
           (self :duration)
           ((make-interval interval) :duration))))
    :contains?
    (fn [self date-time]
      (<= (:epoch self)
          (:epoch date-time)
          (:end self)))
    :after?
    (fn [self date-time]
      (< (:epoch date-time)
         (:later self self)))
    :start
    (fn [self] (:epoch self))
    :end
    (fn [self] (+ (:epoch self) (self :duration)))))

(defn make-period
  "Convenience factory for creating `Period` objects."
  [calendar interval]
  (table/setproto
    (merge (make-calendar calendar)
           (make-interval interval))
    Period))

(defn format-date-time
  ```
  Returns string with formated `dt`.
  
  Optional `local` causes use of local time. Same as `(dyn :local-time)`.
  ```
  [dt &opt local]
  (default local (dyn :local-time))
  (:format (cond-> (make-date-time dt)
                   local :local)))

(defn http-format-date-time
  ```
  Returns string with http formated `dt`.
  
  Optional `local` causes use of local time. Same as `(dyn :local-time)`.
  ```
  [dt]
  (:http-format (make-date-time dt)))

# TODO object API functions
(defn format-date
  "Format `dt` to date string"
  [dt]
  (:format (make-date dt)))

(defn format-interval
  "Format `i` to interval string"
  [i &opt no-secs]
  (:format (make-interval i) no-secs))

(defn format-time
  ```
  Returns string with formated `dt`.
  
  Optional `local` causes use of local time. Same as `(dyn :local-time)`.
  ```
  [dt &opt local]
  (default local (dyn :local-time))
  (def t (cond-> (make-date-time dt)
                 local :local))
  (def h (t :hours))
  (string/format (string "%." (if (zero? h) 1 2) "i:%.2i")
                 h (t :minutes)))

(defn format-today
  "Returns string with formated today's date"
  []
  (:format (today)))

(defn format-now
  "Returns string with formated now's time"
  []
  (format-date-time (now)))

(defn days-ago
  ```
  Returns date time `n` days in history. From optional `tdy` 
  which default to today.
  ```
  [n &opt tdy]
  (default tdy (today))
  (:sooner (make-calendar tdy) (days n)))

(defn days-after
  ```
  Returns date time `n` days in future. From optional `tdy` 
  which default to today.
  ```
  [n &opt tdy]
  (default tdy (today))
  (:later (make-calendar tdy) (days n)))

(defn yesterday
  "Returns yesterday."
  [&opt tdy]
  (days-ago 1 tdy))

(defn weeks-ago
  ```
  Returns date time `n` weeks in history. From optional `tdy` 
  which default to today.
  ```
  [n &opt tdy]
  (days-ago (* n 7) tdy))

(defn start-of-week
  "Returns start of the week `n` weeks in future."
  [n &opt tdy]
  (default tdy (today))
  (days-ago (+ (* 7 (- n)) (tdy :week-day)) tdy))

(defn current-week-start
  "Returns start of the current week for the optional date `tdy`."
  [&opt tdy]
  (start-of-week 0 tdy))

(defn last-week-start
  "Returns date of the start of the last week for optional `tdy`"
  [&opt tdy]
  (start-of-week -1 tdy))

(defn months-ago
  ```
  Returns date time `n` months in history. From optional `tdy` 
  which default to today.
  ```
  [n &opt tdy]
  (default tdy (today))
  (var ds (tdy :month-day))
  (var me (:sooner (make-calendar (merge tdy month-start)) (days 1)))
  (for i 0 (- n)
    (+= ds (inc (me :month-day)))
    (set me (:sooner (make-calendar (merge me month-start)) (days 1))))
  (days-ago ds tdy))

(defn- set-month-start
  [d]
  (merge d month-start))

(defn- inc-month
  [d]
  (merge d (if (= (d :month) 11)
             {:year (inc (d :year)) :month 0}
             {:month (inc (d :month))})))

(defn start-of-month
  "Returns start of the current month for the optional date `tdy`."
  [n &opt tdy]
  (default tdy (today))
  (if (pos? n)
    (do
      (var me (days-ago 1 (set-month-start (inc-month tdy))))
      (var ds (inc (- (me :month-day) (tdy :month-day))))
      (set me (days-after 1 me))
      (for i 1 n
        (set me (days-ago 1 (set-month-start (inc-month me))))
        (+= ds (inc (me :month-day)))
        (set me (days-after 1 me)))
      (days-after ds tdy))
    (do
      (var ds (tdy :month-day))
      (var me (days-ago 1 (set-month-start tdy)))
      (for i 0 (- n)
        (+= ds (inc (me :month-day)))
        (set me (days-ago 1 (set-month-start me))))
      (days-ago ds tdy))))

# TODO docs optional tdy vvv
(defn current-month-start
  "Returns current month start"
  [&opt tdy]
  (start-of-month 0 tdy))

(defn last-month-start
  "Returns last month start"
  [&opt tdy]
  (start-of-month -1 tdy))

(defn start-of-year
  "Returns year start"
  [n &opt tdy]
  (default tdy (today))
  (make-date (merge tdy {:year (+ (tdy :year) n)} year-start month-start)))

(defn current-year-start
  "Returns current month start"
  [&opt tdy]
  (start-of-year 0 tdy))

(defn human
  "Returns string with human representaiton of the `dt`"
  [dt &opt dtn]
  (def cn (make-calendar (or dtn (now))))
  (def cdt (make-calendar dt))
  (cond
    (:contains? (make-period (:sooner cn {:minutes 1}) {:minutes 2}) cdt)
    "now"
    (:contains? (make-period (:sooner cn {:minutes 15}) {:minutes 30}) cdt)
    "about now"
    (:before? (make-calendar (:sooner cn {:hours (cn :hours)})) cdt)
    "today"
    (:before? (make-calendar (:sooner cn {:days 1 :hours (cn :hours)})) cdt)
    "yesterday"
    (:contains? (make-period (:sooner cn {:days 7})
                             {:days 6}) cdt)
    (:str-week-day cdt :long)
    (:contains? (make-period (:sooner cn {:days 28})
                             {:days 27}) cdt)
    (let [dist (math/ceil (/ (- (:epoch cn) (:epoch cdt))
                             (* 7 24 3600)))]
      (string dist " weeks ago"))
    (:contains? (make-period (:sooner cn {:days 364})
                             {:days 338}) cdt)
    (let [dist (math/ceil (/ (- (:epoch cn) (:epoch cdt))
                             (* 30 24 3600)))]
      (string dist " months ago"))
    (= (dec (cn :year)) (cdt :year))
    "last year"))
# TODO docs optional tdy ^^^

