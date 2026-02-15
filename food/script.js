// ===== MENU DATA =====
// Edit these items to match your real menu. Add/remove as you like.

const menuData = {
    indian: [
        // VEG SNACKS
        {
            name: "Papri Chat",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Spring Roll",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1613844237701-8f3664fc2eff?w=600&q=80"
        },
        {
            name: "Noodles",
            desc: "Veg Snacks",
            price: "$9.99",
            img: "https://images.unsplash.com/photo-1585032226651-759b368d7246?w=600&q=80"
        },
        {
            name: "Manchurian",
            desc: "Veg Snacks",
            price: "$10.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Bhel Puri",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80"
        },
        {
            name: "Corn Masala",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600&q=80"
        },
        {
            name: "Veg Momo",
            desc: "Veg Snacks",
            price: "$9.99",
            img: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&q=80"
        },
        {
            name: "Burger Noodles Vala",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80"
        },
        {
            name: "Hot Dog",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1612392166886-ee2f8d0e4b3b?w=600&q=80"
        },
        {
            name: "Potato Chilli",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Gol Gappe Unlimited",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80"
        },
        {
            name: "Dahi Golgappa",
            desc: "Veg Snacks",
            price: "$7.99",
            img: "https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80"
        },
        {
            name: "Allo Tikki",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Samosa Chat",
            desc: "Veg Snacks",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Pav Bhaji",
            desc: "Veg Snacks",
            price: "$9.99",
            img: "https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80"
        },
        
        // NON VEG SNACKS
        {
            name: "Chilli Chicken",
            desc: "Non Veg Snacks",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?w=600&q=80"
        },
        {
            name: "Chicken 65",
            desc: "Non Veg Snacks",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Garlic Chicken",
            desc: "Non Veg Snacks",
            price: "$14.99",
            img: "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?w=600&q=80"
        },
        {
            name: "Chicken Manchurian",
            desc: "Non Veg Snacks",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Dynamic Chicken",
            desc: "Non Veg Snacks",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Fried Chicken",
            desc: "Non Veg Snacks",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Amritsari Fish Fry",
            desc: "Non Veg Snacks",
            price: "$14.99",
            img: "https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=600&q=80"
        },
        {
            name: "Chilli Fish",
            desc: "Non Veg Snacks",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=600&q=80"
        },
        
        // VEG TANDOORI ZYKA
        {
            name: "Paneer Tikka",
            desc: "Veg Tandoori Zyka",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Afgani Paneer",
            desc: "Veg Tandoori Zyka",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Hara Bhara Paneer",
            desc: "Veg Tandoori Zyka",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Tandoori Champ",
            desc: "Veg Tandoori Zyka",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Afgani Champ",
            desc: "Veg Tandoori Zyka",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Tandoori Momos",
            desc: "Veg Tandoori Zyka",
            price: "$11.99",
            img: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&q=80"
        },
        {
            name: "Tandoori Mushroom",
            desc: "Veg Tandoori Zyka",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Veg Seekh",
            desc: "Veg Tandoori Zyka",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        
        // NON VEG ZYKA
        {
            name: "Tandoori Chicken",
            desc: "Non Veg Zyka - Full $21.99 / Half $15.99",
            price: "$21.99",
            img: "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?w=600&q=80"
        },
        {
            name: "Chicken Tikka",
            desc: "Non Veg Zyka",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Chicken Afgani",
            desc: "Non Veg Zyka - Full $22.99 / Half $15.99",
            price: "$22.99",
            img: "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?w=600&q=80"
        },
        {
            name: "Lollipop Chicken",
            desc: "Non Veg Zyka",
            price: "$14.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Chicken Angara",
            desc: "Non Veg Zyka",
            price: "$22.99",
            img: "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?w=600&q=80"
        },
        {
            name: "Tandoori Chicken Butter Vala Delhi Style",
            desc: "Non Veg Zyka - Full $22.99 / Half $15.99",
            price: "$22.99",
            img: "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?w=600&q=80"
        },
        {
            name: "Tandoori Fish",
            desc: "Non Veg Zyka",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=600&q=80"
        },
        {
            name: "Chicken Seekh Kabab",
            desc: "Non Veg Zyka",
            price: "$15.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Lamb Seekh Kabab",
            desc: "Non Veg Zyka",
            price: "$15.99",
            img: "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&q=80"
        },
        
        // AMRITSARI ZYKA
        {
            name: "Cholle Bature",
            desc: "Amritsari Zyka",
            price: "$11.99",
            img: "https://images.unsplash.com/photo-1626132647523-66f5bf380027?w=600&q=80"
        },
        {
            name: "Puri Cholle",
            desc: "Amritsari Zyka",
            price: "$11.99",
            img: "https://images.unsplash.com/photo-1626132647523-66f5bf380027?w=600&q=80"
        },
        {
            name: "Amritsari Naan with Cholle",
            desc: "Amritsari Zyka",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Chur Chur Naan with Chole and Dal",
            desc: "Amritsari Zyka",
            price: "$15.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Nutri Kulcha",
            desc: "Amritsari Zyka",
            price: "$11.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        
        // ROCK AND ROLL NATION
        {
            name: "Egg Roll",
            desc: "Rock and Roll Nation",
            price: "$8.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Chicken Tikka Roll",
            desc: "Rock and Roll Nation",
            price: "$9.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Chilli Chicken Roll",
            desc: "Rock and Roll Nation",
            price: "$10.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Paneer Tikka Roll",
            desc: "Rock and Roll Nation",
            price: "$9.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        {
            name: "Soya Champ Roll",
            desc: "Rock and Roll Nation",
            price: "$9.99",
            img: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&q=80"
        },
        
        // SHAKES
        {
            name: "Oreo Shake",
            desc: "Shakes",
            price: "$7.99",
            img: "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&q=80"
        },
        {
            name: "Kit Kat Shake",
            desc: "Shakes",
            price: "$7.99",
            img: "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&q=80"
        },
        {
            name: "Chocolate Shake",
            desc: "Shakes",
            price: "$7.99",
            img: "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&q=80"
        },
        {
            name: "Milk Badam",
            desc: "Shakes",
            price: "$7.99",
            img: "https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?w=600&q=80"
        },
        {
            name: "Pista Shake",
            desc: "Shakes",
            price: "$7.99",
            img: "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&q=80"
        },
        {
            name: "Sweet Lassi",
            desc: "Shakes",
            price: "$3.99",
            img: "https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?w=600&q=80"
        },
        {
            name: "Mango Lassi",
            desc: "Shakes",
            price: "$3.99",
            img: "https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?w=600&q=80"
        },
        {
            name: "Rose Lassi",
            desc: "Shakes",
            price: "$3.99",
            img: "https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?w=600&q=80"
        },
        
        // MAIN VEG
        {
            name: "Dal Makhni",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600&q=80"
        },
        {
            name: "Dal Fry Yellow",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600&q=80"
        },
        {
            name: "Dal Bukara",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600&q=80"
        },
        {
            name: "Shahi Paneer",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Paneer Tikka Masala",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Paneer Butter Masala",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Paneer Do Pyaja",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Punjabi Chilli Paneer",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Paneer Methi Malai",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Tawa Paneer",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Paneer Bhurji",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Palak Paneer",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Palak Channa",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Palak Kofta",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Champ Masala",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Tandoori Champ Masala",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Champ Methi Malai",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Kofta Curry",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Mushroom Masala",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Mix Veg",
            desc: "Main Veg",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&q=80"
        },
        {
            name: "Jeera Allo",
            desc: "Main Veg",
            price: "$12.99",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        
        // NON VEG MAIN
        {
            name: "Tandoori Chicken Masala",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Cream Chicken",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Chicken Methi Malai",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Dhaba Style Chicken",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Punjabi Butter Chicken",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Keema Chicken",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Tawa Chicken",
            desc: "Non Veg Main",
            price: "$17.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Punjabi Chilli Chicken",
            desc: "Non Veg Main",
            price: "$15.99",
            img: "https://images.unsplash.com/photo-1610057099431-d73a1c9d2f2f?w=600&q=80"
        },
        {
            name: "Rara Chicken",
            desc: "Non Veg Main",
            price: "$17.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Palak Chicken",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Kali Mirch Chicken",
            desc: "Non Veg Main",
            price: "$16.99",
            img: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&q=80"
        },
        {
            name: "Goat Masala",
            desc: "Non Veg Main",
            price: "$17.99",
            img: "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&q=80"
        },
        {
            name: "Dhaba Style Goat",
            desc: "Non Veg Main",
            price: "$17.99",
            img: "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&q=80"
        },
        {
            name: "Palak Mutton",
            desc: "Non Veg Main",
            price: "$17.99",
            img: "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&q=80"
        },
        {
            name: "Mutton Masala",
            desc: "Non Veg Main",
            price: "$17.99",
            img: "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&q=80"
        },
        {
            name: "Mutton Keema",
            desc: "Non Veg Main",
            price: "$17.99",
            img: "https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&q=80"
        },
        {
            name: "Fish Curry",
            desc: "Non Veg Main",
            price: "$18.99",
            img: "https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=600&q=80"
        },
        {
            name: "Fish Masala",
            desc: "Non Veg Main",
            price: "$18.99",
            img: "https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=600&q=80"
        },
        
        // ROTI
        {
            name: "Tandoori Roti",
            desc: "Roti",
            price: "$2.49",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Butter Roti",
            desc: "Roti",
            price: "$2.49",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Lacha Paratha",
            desc: "Roti",
            price: "$3.49",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Pudina Paratha",
            desc: "Roti",
            price: "$3.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Mirch Paratha",
            desc: "Roti",
            price: "$3.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Allo Paratha",
            desc: "Roti",
            price: "$3.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Onion Paratha",
            desc: "Roti",
            price: "$3.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Butter Naan",
            desc: "Roti",
            price: "$3.49",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Garlic Naan",
            desc: "Roti",
            price: "$3.49",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Tawa Roti",
            desc: "Roti",
            price: "$1.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Butter Tawa Roti",
            desc: "Roti",
            price: "$2.49",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Keema Naan (Chicken)",
            desc: "Roti",
            price: "$4.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        {
            name: "Keema Naan (Mutton)",
            desc: "Roti",
            price: "$4.99",
            img: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80"
        },
        
        // RICE
        {
            name: "Steam Rice",
            desc: "Rice",
            price: "$4.99",
            img: "https://images.unsplash.com/photo-1516684732162-798a0062be99?w=600&q=80"
        },
        {
            name: "Jeera Rice",
            desc: "Rice",
            price: "$6.99",
            img: "https://images.unsplash.com/photo-1516684732162-798a0062be99?w=600&q=80"
        },
        {
            name: "Paneer 65 Biryani",
            desc: "Rice",
            price: "$13.99",
            img: "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&q=80"
        },
        {
            name: "Chicken Biryani",
            desc: "Rice",
            price: "$14.99",
            img: "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&q=80"
        },
        {
            name: "Goat Biryani",
            desc: "Rice",
            price: "$15.99",
            img: "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&q=80"
        },
        
        // SALAD
        {
            name: "Sirka Pyaaz",
            desc: "Salad",
            price: "$2.99",
            img: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80"
        },
        {
            name: "Green Salad",
            desc: "Salad",
            price: "$5.99",
            img: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80"
        },
        
        // RAITA
        {
            name: "Plain Raita",
            desc: "Raita",
            price: "$1.99",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Special Raita",
            desc: "Raita",
            price: "$3.49",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        },
        {
            name: "Boondi Raita",
            desc: "Raita",
            price: "$2.49",
            img: "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80"
        }
    ],

    "pizza-pasta": [
        {
            name: "Loading our Pizza, Pasta & Grill menu...",
            desc: "Hang tight while we pull the full selection from our master menu file.",
            price: "",
            img: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&q=80"
        }
    ],

    kebabs: [
        {
            name: "Chicken Seekh Kebab",
            desc: "Spiced minced chicken skewers finished over charcoal heat",
            price: "₹360",
            img: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80"
        },
        {
            name: "Mutton Seekh Kebab",
            desc: "Juicy lamb mince with garam masala & coriander",
            price: "₹420",
            img: "https://images.unsplash.com/photo-1606131731446-5568d87113aa?w=600&q=80"
        },
        {
            name: "Afghani Chicken Tikka",
            desc: "Creamy cashew marinade, slow-roasted for a smoky bite",
            price: "₹410",
            img: "https://images.unsplash.com/photo-1608039829574-76be18af9688?w=600&q=80"
        },
        {
            name: "Tandoori Chicken (Half)",
            desc: "Classic yogurt & chilli rub with lemon butter finish",
            price: "₹380",
            img: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80"
        },
        {
            name: "Reshmi Kebab",
            desc: "Silky chicken malai kebabs grilled to a golden char",
            price: "₹390",
            img: "https://images.unsplash.com/photo-1593030668930-813ab8f2998d?w=600&q=80"
        },
        {
            name: "Paneer Tikka",
            desc: "Charred cottage cheese with peppers & ajwain",
            price: "₹320",
            img: "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80"
        },
        {
            name: "Tandoori Soya Chaap",
            desc: "Protein-packed chaap bathed in smoky tandoori spices",
            price: "₹300",
            img: "https://images.unsplash.com/photo-1514996937319-344454492b37?w=600&q=80"
        },
        {
            name: "Charcoal Lamb Chops",
            desc: "Garlic & rosemary marinated chops grilled medium",
            price: "₹520",
            img: "https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&q=80"
        }
    ]
};

// ===== MENU DOM TARGETS =====
const menuGrid = document.getElementById('menu-grid');
const categoryBtns = document.querySelectorAll('.cat-btn');
const defaultCategory = document.body.dataset.defaultCategory || categoryBtns[0]?.dataset.category || 'indian';
let currentCategory = defaultCategory;
const cartPanel = document.getElementById('cart-panel');
const cartItemsList = document.getElementById('cart-items');
const cartTotalAmount = document.getElementById('cart-total-amount');
const cartCountLabel = document.getElementById('cart-count');
const cartCheckoutBtn = document.getElementById('cart-checkout');
const cartClearBtn = document.getElementById('cart-clear');
const ORDER_PHONE_NUMBER = '+61123456789';
const CART_STORAGE_KEY = 'restaurant-cart';
const cartItems = [];
loadCartFromStorage();

// ===== CSV-DRIVEN MENU (Pizza / Pasta / Grill) =====
const fallbackMenuImage = 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80';

const categoryImageMap = {
    'Pizzas (Standard)': 'https://images.unsplash.com/photo-1548365328-9171ff78e1f0?w=600&q=80',
    'Gourmet Pizzas': 'https://images.unsplash.com/photo-1601924582971-6e804f2bf71d?w=600&q=80',
    'Perfect Pastas': 'https://images.unsplash.com/photo-1473093226795-af9932fe5856?w=600&q=80',
    'Parmas': 'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?w=600&q=80',
    'Burgers Grill': 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&q=80',
    'Soya Chaap': 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&q=80',
    'Fish & Chips': 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=600&q=80',
    'Calzones': 'https://images.unsplash.com/photo-1542831371-d531d36971e6?w=600&q=80',
    'Nitro Sides': 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=600&q=80',
    'Dessert': 'https://images.unsplash.com/photo-1470337458703-46ad1756a187?w=600&q=80',
    'Drinks': 'https://images.unsplash.com/photo-1468465226960-8899e992537c?w=600&q=80'
};

const pizzaPastaCsv = `Category,Item,Price,Description/Notes
Pizzas (Standard),Herb & Garlic,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Margherita,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Pepperoni,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Hawaiian,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Capricciosa,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Meat & Cheese,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Mushroom,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Vegetarian,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Big Cheese,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Chicken Pineapple,$12.00,"Medium $12, Large $14"
Pizzas (Standard),Mexicana,$12.00,"Medium $12, Large $14"
Dessert,Nutella Pizza,$12.00,
Dessert,Strawberry Calzone,$12.00,
Drinks,Shakes,$7.00,
Drinks,Energy Drink,$4.50,
Drinks,Cold Drinks,$3.50,
Gourmet Pizzas,BBQ Chicken,$16.00,
Gourmet Pizzas,Peri Peri Chicken,$16.00,
Gourmet Pizzas,Tandoori Chicken,$16.00,
Gourmet Pizzas,Gourmet Meats,$16.00,
Gourmet Pizzas,Mediterranean Lamb,$16.00,
Gourmet Pizzas,Tandoori Pannier,$16.00,
Gourmet Pizzas,Gourmet Vegetarian,$16.00,
Gourmet Pizzas,Potato & Pumpkin,$16.00,
Gourmet Pizzas,Roast Vegetable,$16.00,
Gourmet Pizzas,Corn Pizza,$16.00,
Gourmet Pizzas,Classic Farmhouse,$16.00,
Gourmet Pizzas,Butter Chicken,$16.00,
Parmas,Pepperoni,$14.00,
Parmas,Tropical,$14.00,
Parmas,Mexican,$14.00,
Parmas,Meat Lover,$14.00,
Parmas,Mushroom Sauce Parma,$23.00,
Burgers Grill,Grilled Chicken Burger,$14.00,
Burgers Grill,Crispy Chicken Burger,$14.00,
Burgers Grill,Hot Flame Chicken Burger,$14.00,
Burgers Grill,Lamb Burger,$14.00,
Burgers Grill,Beef Burger,$14.00,
Burgers Grill,Veggie Burger,$14.00,
Burgers Grill,Vegan Burger,$14.00,
Burgers Grill,Kids Cheese Burger,$10.00,
Soya Chaap,Tandoori Chaap,$14.00,
Soya Chaap,Malai Chaap,$14.00,
Fish & Chips,Fried Fish Flake,$14.00,
Fish & Chips,Grilled Fish Flake,$14.00,
Perfect Pastas,Napoli,$15.00,
Perfect Pastas,Tandoori Veg,$15.00,
Perfect Pastas,Mushroom,$15.00,
Perfect Pastas,Pesto,$15.00,
Perfect Pastas,Veggie,$15.00,
Perfect Pastas,Chicken,$15.00,
Perfect Pastas,Tandoori Chicken,$15.00,
Calzones,BBQ Chicken,$12.00,
Calzones,Mediterranean Lamb,$12.00,
Calzones,Tandoori Calzones,$12.00,
Calzones,Mexican,$12.00,"Price listed as $12 and $14"
Calzones,Vegetarian/Vegan,$12.00,
Calzones,Meat Lover,$14.00,
Nitro Sides,Chicken Wings with Fries,$14.00,
Nitro Sides,Steak Cut Hot Chips,$10.00,
Nitro Sides,Seasoned Wedges,$10.00,
Nitro Sides,Sweet Potato Chips,$10.00,
Nitro Sides,Chicken Tenders,$10.00,
Nitro Sides,Cheesy Garlic Bread,$10.00,
Nitro Sides,Greek Salad,$10.00,
Nitro Sides,Chicken Schnitzel,$10.00,`;

populatePizzaMenuFromCsv();

function populatePizzaMenuFromCsv() {
    const rows = parseCsv(pizzaPastaCsv);
    const structuredItems = rows
        .filter(row => row.Item && row.Category)
        .map(row => ({
            name: row.Item.trim(),
            desc: buildCsvDescription(row),
            price: getPriceLabel(row.Price),
            img: getImageForCategory(row.Category)
        }));

    if (structuredItems.length) {
        menuData['pizza-pasta'] = structuredItems;
        if (currentCategory === 'pizza-pasta') {
            renderMenu('pizza-pasta');
        }
    }
}

function buildCsvDescription(row) {
    const category = row.Category ? row.Category.trim() : '';
    const notes = row['Description/Notes']?.trim();
    return [category, notes].filter(Boolean).join(' • ');
}

function getPriceLabel(price) {
    const value = (price || '').trim();
    return value || 'Ask for today\'s price';
}

function getImageForCategory(category) {
    return categoryImageMap[category] || fallbackMenuImage;
}

function parseCsv(text) {
    const lines = text.split(/\r?\n/).filter(line => line.trim().length);
    if (!lines.length) return [];

    const headers = splitCsvLine(lines[0]);
    return lines.slice(1).map(line => {
        const cells = splitCsvLine(line);
        return headers.reduce((acc, header, index) => {
            acc[header] = cells[index] || '';
            return acc;
        }, {});
    });
}

function splitCsvLine(line) {
    const cells = [];
    let current = '';
    let inQuotes = false;

    for (let i = 0; i < line.length; i++) {
        const char = line[i];

        if (char === '"') {
            if (inQuotes && line[i + 1] === '"') {
                current += '"';
                i++;
            } else {
                inQuotes = !inQuotes;
            }
        } else if (char === ',' && !inQuotes) {
            cells.push(current.trim());
            current = '';
        } else {
            current += char;
        }
    }

    cells.push(current.trim());
    return cells;
}

function escapeAttribute(value = '') {
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

function extractPriceValue(priceText = '') {
    const cleaned = priceText.replace(/,/g, '');
    const match = cleaned.match(/(\d+(?:\.\d+)?)/);
    return match ? parseFloat(match[1]) : 0;
}

function getCurrencySymbol(priceText = '') {
    const match = priceText.match(/[₹$€£]/);
    return match ? match[0] : '₹';
}

function formatCurrency(amount, symbol = '₹') {
    if (!amount || isNaN(amount)) return 'Call to order';
    return `${symbol}${amount.toFixed(2)}`;
}


function renderMenu(category) {
    if (!menuGrid || !menuData[category]) return;

    currentCategory = category;
    const items = menuData[category];
    menuGrid.innerHTML = '';

    items.forEach(item => {
        const description = item.desc || '';
        const priceLabel = item.price || '';
        const safeName = escapeAttribute(item.name);
        const safePrice = escapeAttribute(priceLabel);
        const numericPrice = extractPriceValue(priceLabel);
        const currencySymbol = getCurrencySymbol(priceLabel);
        const card = document.createElement('div');
        card.className = 'menu-card';
        card.innerHTML = `
            <img class="menu-card-img" src="${item.img}" alt="${item.name}" loading="lazy"
                 onerror="this.src='https://via.placeholder.com/600x400?text=${encodeURIComponent(item.name)}'">
            <div class="menu-card-body">
                <h3>${item.name}</h3>
                <p class="desc">${description}</p>
                <div class="menu-card-foot">
                    <span class="price">${priceLabel || 'Price on call'}</span>
                    <button class="add-cart-btn"
                        data-name="${safeName}"
                        data-price="${safePrice}"
                        data-value="${numericPrice}"
                        data-currency="${currencySymbol}">
                        Add to Cart
                    </button>
                </div>
            </div>
        `;
        menuGrid.appendChild(card);
    });

    // Re-trigger animation
    menuGrid.style.animation = 'none';
    menuGrid.offsetHeight; // force reflow
    menuGrid.style.animation = '';
}

// ===== CART LOGIC =====
if (menuGrid) {
    menuGrid.addEventListener('click', handleMenuGridClick);
}

cartItemsList?.addEventListener('click', handleCartListClick);
cartCheckoutBtn?.addEventListener('click', handleCartCheckout);
cartClearBtn?.addEventListener('click', clearCart);
renderCart();

function handleMenuGridClick(event) {
    const btn = event.target.closest('.add-cart-btn');
    if (!btn) return;
    const name = btn.dataset.name;
    if (!name) return;
    const priceLabel = btn.dataset.price || 'Price on call';
    const unitPrice = Number(btn.dataset.value) || 0;
    const currency = btn.dataset.currency || '₹';

    addToCart({
        name,
        priceLabel,
        unitPrice,
        currency
    });
}

function handleCartListClick(event) {
    const removeBtn = event.target.closest('.cart-item-remove');
    if (!removeBtn) return;
    const name = removeBtn.dataset.name;
    if (!name) return;
    removeCartItem(name);
}

function handleCartCheckout() {
    if (!cartItems.length) return;
    window.location.href = `tel:${ORDER_PHONE_NUMBER}`;
}

function addToCart(item) {
    if (!cartItemsList) return;
    const existing = cartItems.find(entry => entry.name === item.name);
    if (existing) {
        existing.qty += 1;
    } else {
        cartItems.push({ ...item, qty: 1 });
    }
    renderCart();
    saveCartToStorage();
}

function removeCartItem(name) {
    const index = cartItems.findIndex(entry => entry.name === name);
    if (index === -1) return;
    cartItems.splice(index, 1);
    renderCart();
    saveCartToStorage();
}

function clearCart() {
    if (!cartItems.length) return;
    cartItems.length = 0;
    renderCart();
    saveCartToStorage();
}

function renderCart() {
    if (!cartItemsList) return;
    cartItemsList.innerHTML = '';

    if (!cartItems.length) {
        const empty = document.createElement('li');
        empty.className = 'cart-empty';
        empty.textContent = 'Your cart is empty. Tap "Add to Cart" to begin.';
        cartItemsList.appendChild(empty);
    } else {
        cartItems.forEach(item => {
            const li = document.createElement('li');
            li.className = 'cart-item';
            li.innerHTML = `
                <div>
                    <h4>${item.name}</h4>
                    <small>${item.priceLabel}</small>
                </div>
                <div class="cart-item-meta">
                    <strong>x${item.qty}</strong><br>
                    <span>${item.unitPrice ? formatCurrency(item.unitPrice * item.qty, item.currency) : 'Call us'}</span>
                    <button class="cart-item-remove" data-name="${escapeAttribute(item.name)}" type="button">Remove</button>
                </div>
            `;
            cartItemsList.appendChild(li);
        });
    }

    const totalQty = cartItems.reduce((sum, item) => sum + item.qty, 0);
    if (cartCountLabel) {
        cartCountLabel.textContent = `${totalQty} item${totalQty === 1 ? '' : 's'}`;
    }

    const totalValue = cartItems.reduce((sum, item) => sum + (item.unitPrice * item.qty), 0);
    const activeCurrency = cartItems.find(item => item.unitPrice > 0)?.currency || '₹';
    if (cartTotalAmount) {
        cartTotalAmount.textContent = totalValue ? formatCurrency(totalValue, activeCurrency) : 'Call to order';
    }

    if (cartCheckoutBtn) {
        cartCheckoutBtn.disabled = !cartItems.length;
    }
    if (cartClearBtn) {
        cartClearBtn.disabled = !cartItems.length;
    }
}

function loadCartFromStorage() {
    if (typeof localStorage === 'undefined') return;
    try {
        const stored = localStorage.getItem(CART_STORAGE_KEY);
        if (!stored) return;
        const parsed = JSON.parse(stored);
        if (!Array.isArray(parsed)) return;
        parsed.forEach(item => {
            if (!item || !item.name) return;
            cartItems.push({
                name: item.name,
                priceLabel: item.priceLabel || 'Price on call',
                unitPrice: Number(item.unitPrice) || 0,
                currency: item.currency || '₹',
                qty: Number(item.qty) > 0 ? Number(item.qty) : 1
            });
        });
    } catch (error) {
        console.warn('Unable to load saved cart:', error);
    }
}

function saveCartToStorage() {
    if (typeof localStorage === 'undefined') return;
    try {
        localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(cartItems));
    } catch (error) {
        console.warn('Unable to save cart:', error);
    }
}

function setActiveButton(category) {
    categoryBtns.forEach(btn => {
        btn.classList.toggle('active', btn.dataset.category === category);
    });
}

// Button click handlers
categoryBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        renderMenu(btn.dataset.category);
        setActiveButton(btn.dataset.category);
    });
});

// Load default category
renderMenu(defaultCategory);
setActiveButton(defaultCategory);


// ===== QR CODE & SHARE LINK =====
const pageURL = window.location.href;
const shareLinkInput = document.getElementById('share-link');
shareLinkInput.value = pageURL;

// Generate QR code
try {
    new QRCode(document.getElementById('qr-code'), {
        text: pageURL,
        width: 180,
        height: 180,
        colorDark: "#1a1a2e",
        colorLight: "#ffffff",
        correctLevel: QRCode.CorrectLevel.H
    });
} catch (e) {
    console.log('QR code library not loaded:', e);
}

// Copy link function
function copyLink() {
    const input = document.getElementById('share-link');
    input.select();
    input.setSelectionRange(0, 99999);
    navigator.clipboard.writeText(input.value).then(() => {
        const btn = document.getElementById('copy-link-btn');
        btn.textContent = 'Copied!';
        setTimeout(() => btn.textContent = 'Copy Link', 2000);
    });
}
