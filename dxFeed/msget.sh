#!/bin/bash
trap "echo Booh!; exit 1" SIGINT SIGTERM

all_tables=( OperationRatiosRestate OperationRatiosAOR LongDescriptions MergersAndAcquisitions AssetClassification FinancialStatementsAOR IndexParticipationByCId CompanyProfile CorporateCalendars HistoricalAssetClassification Segmentation FinancialStatementsRestate Company ShareClass TrailingReturns CashDividents StockSplits PriceStatistics Spinoffs EarningReportsRestate AlphaBeta ShareClassProfile ValuationRatios HistoricalReturns Price EarningRatiosAOR EarningReportsAOR EarningRatiosRestate )
not_all_tables=( OperationRatiosRestate OperationRatiosAOR LongDescriptions )
indexes=( TorontoStockIndex SnPSmallCap SnP SnPMidCap DowJones SnPTop100 )
#symbols=( XOM MSFT IBM RDS.A BHP CHL JNJ BBL ORCL PBR )
symbols=( WAG SLB NOV ALL DELL GOOG USB COP PM JPM ) # This array should be sorted alphabetically
#symbols=( DRI PX PCS PNC AIG NDAQ DE HAS MUR MCO ) 


dirname=~/mssanity/`date +"%d%m-%H%M"`
if [ ! -d ~/mssanity ]; then
  mkdir ~/mssanity
fi
mkdir $dirname 


pushd /opt/mddqa

#echo ${symbols[@]} | sed 's/ /\n/g' | nawk '{ printf("%8s", $1) }'; echo
printf "%30s "; for s in ${symbols[@]}; do printf "%8s" $s; done; echo

for table in ${all_tables[@]}
do
  mkdir $dirname/$table

  for symbol in ${symbols[@]}
  do
    HOME=/opt/mddqa sh ./mstools/get localhost:7440 $symbol $table > $dirname/$table/$symbol
  done
  printf "%30s " $table
  ls -l $dirname/$table/ | tail +2 | awk '{ print $5 }' | nawk '{ printf("%8s", $1) }'; echo
done

mkdir $dirname/indexes
for index in ${indexes[@]}; do
  HOME=/opt/mddqa sh ./mstools/get localhost:7440 $index > $dirname/indexes/$index
done
echo
ls -l $dirname/indexes/ | tail +2 | awk '{ printf("%30s: %8s\n", $9, $5) }' | head -6
#ls -lh $dirname/indexes/ | awk '{ print $9, $5 }' | nawk '$1=$1' ORS=", " OFS=": "

popd
