---
layout: about
---
### Payout to address [{{ delegator_id }}](https://tzstats.com/{{ delegator_id }}){:target="_blank"}:
<style>
table.nested_table {
border-collapse: collapse;
margin-bottom: 0px;
border: 0px;
}
table td.nested_td {
border: 0px;
text-align: right;
margin-bottom: 1px;
padding: 0px 15px;
}
</style>
<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
<script>
function expand_details(cycle_id) 
{   
    if ($("#caret_"+cycle_id).hasClass("fa-caret-right")){
        $(".row_details").hide();
        $(".cycle_arrow").removeClass("fa-caret-down").addClass("fa-caret-right");
        $("#row_details_"+cycle_id).show();
        $("#caret_"+cycle_id).removeClass("fa-caret-right").addClass("fa-caret-down");
    }
    else {
        $("#row_details_"+cycle_id).hide();
        $("#caret_"+cycle_id).removeClass("fa-caret-down").addClass("fa-caret-right");
    }    
}
</script>

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
                <td>
					<label for="details" onclick="expand_details({{cycle_id}})">View details</label>
                    <i id="caret_{{cycle_id}}" class="fa fa-caret-right cycle_arrow" onclick="expand_details({{cycle_id}})"></i>
				</td>
           </tr>
           <tr id="row_details_{{cycle_id}}" class="row_details" style="display:none">
                <td class="delegator_details" colspan="4">
                    <table class="nested_table" >
                            <tr>
                                <td class="nested_td">Estimated reward for cycle {{ cycle_id }}, ꜩ: </td> 
                                <td class="nested_td">{{ delegator_details_for_cycle[("estimatedRewards")] }}</td>
                            </tr>
                            {% if delegator_details_for_cycle[("payoutWithheldDebt")] %}
                            <tr>
                                <td class="nested_td">Debt amount for cycle {{ delegator_details_for_cycle[("withheldDebtForCycle")] }}, ꜩ:</td>
                                <td class="nested_td">{{ delegator_details_for_cycle[("payoutWithheldDebt")] }}</td> 
                            </tr>
                            {% endif %}
                            <tr>
                                <td class="nested_td">Total paid in cycle {{ delegator_details_for_cycle[("paid_in_cycle")] }}, ꜩ:</td>
                                <td class="nested_td">{{delegator_details_for_cycle[("payoutAmount")] }}</td> 
                            </tr>
                    </table>
                </td>
            </tr>
        {%- endfor %}
    </tbody>
</table>

[How do payouts work ?](https://hodl.farm/faq.html#how-do-payouts-work-)

