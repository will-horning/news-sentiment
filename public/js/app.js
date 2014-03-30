$(document).ready(function(){
    $.getJSON("/get_date2sentiment/", {},
        function(date2sentiment){    
            var ctx = document.getElementById("myChart").getContext("2d");
            var data = {
                labels: date2sentiment["dates"],
                datasets : [
                    {
                        fillColor : "rgba(128,128,220,0.5)",
                        strokeColor : "rgba(128,128,220,1)",
                        data : date2sentiment["sentiments"]
                    }]
            };
            var myNewChart = new Chart(ctx).Bar(data);
        }
    );
})