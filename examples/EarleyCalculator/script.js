
document.addEventListener('DOMContentLoaded', (event) => {
	var screen = document.getElementById("screen")
	var ops = document.getElementsByClassName("operator");
	for (let i = 0; i < ops.length; i++) {
		var item = ops[i]
		
		item.addEventListener('click', function(event) {
			let curitem = event.srcElement
			if (curitem.id == "lp" || curitem.id == "rp") {
				screen.value += curitem.value
				return;
			}
			let re = new RegExp(`\\${curitem.value}$`)
			screen.value += !screen.value.match(re) ? curitem.value : ""
		})
	}
	document.getElementById("+").onclick = function() {
		screen.value += !screen.value.match(/\+$/) ? "+" : ""
	}
	var nums = document.getElementsByClassName("number");
	for (let i = 0; i < nums.length; i++) {
		
		var item = nums[i]
		
		item.addEventListener("click", function(event) {
			console.log(event.srcElement.value)
			screen.value = (screen.value == "0" ? event.srcElement.value : screen.value + event.srcElement.value)
		})
	}
	document.getElementById('decimal').addEventListener('click', function() {
		screen.value += screen.value.match(/\d$/) ? "." : ""
	})
	document.getElementById('DEL').addEventListener('click', function() {
		screen.value = screen.value.length != 1 ? screen.value.slice(0, -1) : "0"
	})
	document.getElementById('AC').addEventListener('click', function() {
		screen.value = "0"
	})
	
})


