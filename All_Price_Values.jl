using JuMP,  DataFrames, DataArrays, Clp

## The path where data files are located
cd("/Users/zvihuber/Desktop/Research/")

## while loop to determine how many files exist --> how many prices vectors to produce
num_of_files = 1

while (isfile(string("./data/daminst-", num_of_files,"/areas.csv")) == true)
#    print(count, " ")
    num_of_files += 1
end
num_of_files -= 1
#print(num_of_files)

prices_severaldays = []

for j in 1:num_of_files
    ssid=j
    areas=readtable(string("./data/daminst-", ssid,"/areas.csv"))                   # list of bidding zones
    periods=readtable(string("./data/daminst-", ssid,"/periods.csv"))               # list of periods considered
    hourly=readtable(string("./data/daminst-", ssid,"/hourly_quad.csv"))            # classical demand and offer bid curves
    mp_headers=readtable(string("./data/daminst-", ssid,"/mp_headers.csv"))         # MP bids: location, fixed cost, variable cost

    ## Genrating random data for the FC column ##
    nrows_mpHeaders = size(mp_headers, 1)                                                             # Number of rows in mp_headers
    minFC = minimum(mp_headers[3])                                                          # Min value in FC col (lower boundary)
    maxFC = maximum(mp_headers[3])                                                          # Max value in FC col (upper boundary)
    for k in 1:nrows_mpHeaders
        mp_headers[3][k] = rand(minFC:maxFC)
        #print(mp_headers[3][k], " ")
    end

    ## Generating random data for PH/QH pairs in mp_hourly ##
    mp_hourly=readtable(string("./data/daminst-", ssid,"/mp_hourly.csv"))           # the different bid curves associated to a MP bid
    nrows_mpHourly = size(mp_hourly, 1)
    minPH = minimum(mp_hourly[2])
    maxPH = maximum(mp_hourly[2])
    minQH = minimum(mp_hourly[3])
    maxQH = maximum(mp_hourly[3])
    for k in 1:nrows_mpHourly
        mp_hourly[2][k] = rand(minPH:maxPH)
        mp_hourly[3][k] = rand(minQH:maxQH)
    end
    #if j == 1
    #    display(mp_hourly)
    #end

    line_capacities=readtable(string("./data/daminst-", ssid,"/line_cap.csv"))      # tranmission capacities of lines. as of now, a simple "ATC"

    pricecap_up = 3000 # market price range restrictions, upper bound,  current European market rules
    pricecap_down = -500 # market price range restrictions, lower bound, current European market rules (PCR)

    areas = Array(areas)
    periods = Array(periods)

    nbHourly = nrow(hourly)
    nbMp = nrow(mp_headers)
    nbMpHourly = nrow(mp_hourly)
    nbAreas = length(areas)
    nbPeriods = length(periods)

    m = Model(solver = ClpSolver())

    @variable(m, 0<= x[1:nbHourly] <=1) # variables 'x_i, includes the bounds given by conditions (6) and (9) in the slides
    @variable(m, 0<= f[areas, areas, periods] <= 0) # by default/at declaration, a line "doesn't exist", it qlso includes conditions (9)

    for i in 1:nrow(line_capacities)
        setupperbound(f[line_capacities[i,:from], line_capacities[i,:too] , line_capacities[i,:t] ], line_capacities[i,:linecap] ) # conditions (8), setting transmission line capacities
    end

    # executed quantities of the 'hourly bids' for a given location 'loc' and time slot 't'
    @constraint(m, balance[loc in areas, t in periods], sum(x[i]*hourly[i, :QI] for i=1:nbHourly if hourly[i, :LI] == loc && hourly[i, :TI]==t ) == sum(f[loc_orig, loc, t] for loc_orig in areas if loc_orig != loc) - sum(f[loc, loc_dest,t] for loc_dest in areas if loc_dest != loc))

    obj = dot(x,(hourly[:,:QI].data).*(hourly[:,:PI0].data))

    @objective(m, Max,  obj)

    status = solve(m)

    objval=getobjectivevalue(m)

    xval=getvalue(x)
    fval=getvalue(f)

    prices = values(getdual(balance))
    prices_severaldays = vcat(prices_severaldays, values(prices).x)

end
prices_severaldays = prices_severaldays'
#print(prices_severaldays)

prices_location11 = []
for i in 1:2:480
    prices_location11 = vcat(prices_location11, prices_severaldays[i])
end

prices_location12 = []
for i in 2:2:480
    prices_location12 = vcat(prices_location12, prices_severaldays[i])
end

length(prices_location11)
length(prices_location12)
length(prices_severaldays)

#Calculates Statistics
function statistics(x)
    return maximum(Array(x)), minimum(Array(x)), median(Array(x)), mean(Array(x))
end

#Creates a Dictionary with "max", "min", "median", "mean" as keywords
function general_stats(y)
    return Dict("max" => y[1], "min" => y[2], "median" => y[3], "mean" => y[4])
end

#Dictionary for each location
general_statistics_11 = general_stats(statistics(prices_location11))
general_statistics_12 = general_stats(statistics(prices_location12))
