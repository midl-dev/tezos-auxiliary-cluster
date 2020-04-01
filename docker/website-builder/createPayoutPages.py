import json 
import sys
import os
from jinja2 import Template

# 6 - offset to calculate the cycle when the actual payout is processed
payout_offset = int(os.environ["PAYOUT_DELAY"]) + 6 

template_path = sys.argv[1]
save_path = sys.argv[2]

with open('payouts.json') as json_file:
    raw_payouts = json.load(json_file)

#Crreate Payouts by delegator dictionary
payout_by_delegator={}
for cycle_id,cycle_details in raw_payouts["payoutsByCycle"].items():
    for delegator_id,delegator_details in cycle_details["delegators"].items():
        if delegator_id not in payout_by_delegator:
            payout_by_delegator[delegator_id]={}
        delegator_details["paid_in_cycle"]= int(cycle_id)+payout_offset
        delegator_details["balance"]= 'ꜩ{:13,.6f}'.format(int(delegator_details["balance"])/1000000)
        if  "estimatedDifference" in delegator_details:
            delegator_details["estimatedDifference"] = 'ꜩ{:13,.6f}'.format(int(delegator_details["estimatedDifference"])/1000000)
        if  "finalRewards" in delegator_details:
            delegator_details["finalRewards"] = 'ꜩ{:13,.6f}'.format(int(delegator_details["finalRewards"])/1000000)
        if "payoutAmount" in delegator_details:
            delegator_details["payoutAmount"]= 'ꜩ{:13,.6f}'.format(int(delegator_details["payoutAmount"])/1000000)
        else: 
            #the case statement below accomodates legacy data structure before cycle 210
            delegator_details["payoutAmount"]= 'ꜩ{:13,.6f}'.format(int(delegator_details["estimatedRewards"])/1000000)
        if "payoutWithheldDebt" in delegator_details:
            if delegator_details["payoutWithheldDebt"]=="0":
                delegator_details.pop("payoutWithheldDebt")
            else:
                delegator_details["payoutWithheldDebt"]= '-ꜩ{:13,.6f}'.format(int(delegator_details["payoutWithheldDebt"])/1000000)

        delegator_details["estimatedRewards"]= 'ꜩ{:13,.6f}'.format(int(delegator_details["estimatedRewards"])/1000000)
        payout_by_delegator[delegator_id][cycle_id]=delegator_details

for delegator_id,delegator_details in payout_by_delegator.items():   
    template = Template(open(template_path).read()) 
    output = template.render(delegator_id = delegator_id,delegator_details=delegator_details)
    with open("%s/%s.md" % ( save_path, delegator_id), "w") as f:
        f.write(output)
