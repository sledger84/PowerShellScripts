function ConvertGpsData{

    #sets up adding filename and allowing to switch on/off daylight savings times
    Param (
        [parameter(Mandatory=$true)][string]$filename,
        [parameter(Mandatory=$false)][switch]$useDST,
        [parameter(Mandatory=$false)][string]$outputfile = $filename.substring(0,$filename.length-4)+".csv"
    )

    #Sets timezone to be Sydney(Daylight savings) if useDST switch is used
    #otherwise use Brisbane timezone
    if ($useDST){
        $timezone = 'AUS Eastern Standard Time'
    }else{
        $timezone = 'E. Australia Standard Time'
    }

    #set column widths for each columns 
    $pattern = '^(.{5})(.{15})(.{6})(.{10})(.{10})(.{10})(.{14})(.{11})(.{13})(.{13})(.{13})(.{8})(.{12})(.{16})'
    $replace = '$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,'    

    #add commas between each of the columns based on the widths in the pattern
    $gps = (get-content $filename) -replace $pattern,$replace |convertfrom-csv 

    #add extra columns
    $gps |Add-Member -MemberType NoteProperty -Name "RTC-DateTime" -Value $null
    $gps |Add-Member -MemberType NoteProperty -Name DateTime -Value $null
    $gps |Add-Member -MemberType NoteProperty -Name sats_acq -value $null
    $gps |Add-Member -MemberType NoteProperty -Name sats_avail -value $null
    $gps |Add-Member -MemberType NoteProperty -Name "class" -value $null


    #for loop to add data to the new columns
    for ($i = 0;$i -lt $gps.count;$i++){
        #create an array with the 1st and second value in the Sats column and insert to sats_acq and sats_avail columns
        $splitSat = $gps[$i].Sats.Split('/')
        $gps[$i].sats_acq = $splitSat[0]
        $gps[$i].sats_avail = $splitSat[1]

        #checking the sats_acq column to update the class column
        switch -regex ($gps[$i].sats_acq){
            [0-2] {$gps[$i]."class" = "1D"}
            3 {$gps[$i]."class" = "2D"}
            [4-9] {$gps[$i]."class" = "4D"}
            [1-9][0-9] {$gps[$i]."class" = "4D"}
        }

        #read the RTC-Date and RTC-Time fields (appended with +00:00 to specify it is UTC) and tell it to store as UTC
        $gps[$i]."RTC-DateTime" =  [datetime]::parseexact($gps[$i]."RTC-Date"+$gps[$i]."RTC-Time"+" +00:00","yy/MM/ddHH:mm:ss zzz",$null).ToUniversalTime()
        #update datetime column with the relevant timezone info. Daylight savings times will be updated during DST periods if useDST switch is specified
        $gps[$i].DateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($gps[$i]."RTC-DateTime",$timezone)

    }

    #output to a csv file
    #update select-object properties to change order or columns shown
    $gps `
        | Select-Object -Property Index,Status,Sats,RTC-date,RTC-time,FIX-date,FIX-time,'Delta(s)',Latitude,Longitude,'Altitude(m)',HDOP,eRes,'Temperature(C)','Voltage(V)',RTC-DateTime,DateTime,sats_acq,sats_avail,class   `
        | Export-Csv -Path $outputfile -UseQuotes Always

}
