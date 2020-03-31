---
layout: about
---
### Payout to address [{{ delegator_id }}](https://tzstats.com/{{ delegator_id }}){:target="_blank"}:

<table class="{{tableclass}}" id="delegators">
    <thead>
           <th>Rewards cycle</th>
           <th>Balance</th>
           <th>Payout Amount</th>
           <th>Details</th>
    </thead>
    <tbody>
        {%- for cycle_id,delegator_details_for_cycle in delegator_details.items() %}
           <tr>
                <td>{{ cycle_id }}</td>
                <td>ꜩ{{ delegator_details_for_cycle[("balance")] }}</td>          
                <td>ꜩ{{ delegator_details_for_cycle[("payoutAmount")] }}</td> 
                <td><a href="#">details</a></td>
           </tr>
           <tr>
                <td colspan="4"><b>Payout Cycle details</b> 
                    <br/>Estimated reward for {{ cycle_id }}, ꜩ: {{delegator_details_for_cycle[("estimatedRewards")] }}
                {% if delegator_details_for_cycle[("payoutWithheldDebt")] %}
                    <br/>Debt amount for cycle {{ delegator_details_for_cycle[("withheldDebtForCycle")] }}, ꜩ: {{delegator_details_for_cycle[("payoutWithheldDebt")] }}
                {% endif %}
                    <br/>Final payout paid in cycle {{ delegator_details_for_cycle[("paid_in_cycle")] }}, ꜩ: {{delegator_details_for_cycle[("payoutAmount")] }}
                    </td>
            </tr>
        {%- endfor %}
        </tbody>
</table>

[How do payouts work ?](https://hodl.farm/faq.html#how-do-payouts-work-)